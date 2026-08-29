require "fileutils"
require "net/http"
require "uri"

module Liberic
  class EricInstaller
    DEFAULT_VERSION = "43.5.4.0"
    BASE_URL = "https://download.elster.de/download/eric"
    ARTIFACT_SUFFIXES = [
      "Linux-x86_64.jar",
      "Dokumentation.pdf",
      "Dokumentation.zip"
    ].freeze

    class InstallError < StandardError; end

    attr_reader :version, :root

    def initialize(version: DEFAULT_VERSION, root: File.expand_path("..", __dir__), output: $stdout)
      @version = version
      @root = root
      @output = output
      validate_version!
    end

    def major_version
      version.split(".").first
    end

    def filenames
      ARTIFACT_SUFFIXES.map { |suffix| "ERiC-#{version}-#{suffix}" }
    end

    def urls
      filenames.map { |filename| "#{BASE_URL}/#{major_version}/#{filename}" }
    end

    def install_root
      File.join(root, ".eric")
    end

    def downloads_path
      File.join(install_root, "downloads")
    end

    def sdk_home
      File.join(install_root, "ERiC-#{version}", "Linux-x86_64")
    end

    def expected_library
      File.join(sdk_home, "lib", "libericapi.so")
    end

    def install
      check_platform!
      FileUtils.mkdir_p(downloads_path)

      if installed?
        @output.puts "ERiC #{version} is already installed."
        print_environment_setup
        return sdk_home
      end

      archives = urls.zip(filenames).map do |url, filename|
        path = File.join(downloads_path, filename)
        download(url, path) unless File.file?(path)
        path
      end

      archives.each { |archive| extract(archive) }
      validate_installation!
      File.write(installation_marker, "#{version}\n")

      @output.puts "Installed ERiC #{version} in #{install_root}."
      print_environment_setup
      sdk_home
    rescue InstallError
      raise
    rescue SystemCallError => error
      raise InstallError, error.message
    end

    def download(url, destination, redirects: 5)
      @output.puts "Downloading #{url}"
      part = "#{destination}.part"
      FileUtils.rm_f(part)

      stream_download(URI(url), part, redirects)
      File.rename(part, destination)
    rescue StandardError => error
      FileUtils.rm_f(part) if part
      raise error if error.is_a?(InstallError)

      raise InstallError, "download failed for #{url}: #{error.message}"
    end

    def extract(path)
      if File.extname(path) == ".pdf"
        FileUtils.cp(path, install_root)
        return
      end

      require "zip"
      destination_root = File.expand_path(install_root)

      Zip::File.open(path) do |archive|
        archive.each do |entry|
          destination = File.expand_path(entry.name, destination_root)
          unless destination == destination_root || destination.start_with?("#{destination_root}#{File::SEPARATOR}")
            raise InstallError, "invalid archive #{path}: unsafe entry #{entry.name.inspect}"
          end

          FileUtils.mkdir_p(File.dirname(destination))
          entry.extract(destination) { true }
        end
      end
    rescue LoadError
      raise InstallError, "rubyzip is required; run bundle install before eric:install"
    rescue Zip::Error, Errno::ENOENT, Errno::EACCES => error
      raise InstallError, "invalid archive #{path}: #{error.message}"
    end

    private

    def installation_marker
      File.join(install_root, ".installed-#{version}")
    end

    def installed?
      File.file?(installation_marker) && File.file?(expected_library)
    end

    def validate_version!
      return if version.match?(/\A\d+\.\d+\.\d+\.\d+\z/)

      raise InstallError, "invalid ERIC_VERSION #{version.inspect}; expected a version such as 43.5.4.0"
    end

    def check_platform!
      return if RUBY_PLATFORM.match?(/x86_64-linux/)

      raise InstallError, "eric:install supports Linux x86-64 only (current platform: #{RUBY_PLATFORM})"
    end

    def validate_installation!
      return if File.file?(expected_library)

      raise InstallError, "installation is incomplete: expected #{expected_library}"
    end

    def stream_download(uri, destination, redirects)
      request = Net::HTTP::Get.new(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request) do |response|
          case response
          when Net::HTTPSuccess
            File.open(destination, "wb") { |file| response.read_body { |chunk| file.write(chunk) } }
          when Net::HTTPRedirection
            raise InstallError, "too many redirects while downloading #{uri}" if redirects.zero?

            location = response["location"]
            raise InstallError, "redirect without a Location header while downloading #{uri}" unless location

            stream_download(URI.join(uri, location), destination, redirects - 1)
          else
            raise InstallError, "download failed for #{uri}: HTTP #{response.code} #{response.message}"
          end
        end
      end
    end

    def print_environment_setup
      @output.puts
      @output.puts "Set ERIC_HOME in your shell:"
      @output.puts %(export ERIC_HOME="$PWD/.eric/ERiC-#{version}/Linux-x86_64")
      @output.puts "Rake cannot permanently modify the environment of its parent shell."
    end
  end
end

namespace :eric do
  desc "Download and install the ERiC Linux x86-64 SDK and documentation"
  task :install do
    Liberic::EricInstaller.new(version: ENV.fetch("ERIC_VERSION", Liberic::EricInstaller::DEFAULT_VERSION)).install
  rescue Liberic::EricInstaller::InstallError => error
    abort "eric:install failed: #{error.message}"
  end
end
