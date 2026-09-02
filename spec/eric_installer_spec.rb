require "fileutils"
require "rake"
require "stringio"
require "tmpdir"
require "zip"
load File.expand_path("../rakelib/eric.rake", __dir__)

RSpec.describe Liberic::EricInstaller do
  subject(:installer) { described_class.new(version: version, root: root, output: output) }

  let(:version) { "43.5.4.0" }
  let(:root) { Dir.mktmpdir("liberic-installer") }
  let(:output) { StringIO.new }

  after { FileUtils.remove_entry(root) }

  it "derives artifact URLs from the full version and its major version" do
    expect(installer.urls).to eq([
      "https://download.elster.de/download/eric/eric_43/ERiC-43.5.4.0-Linux-x86_64.jar",
      "https://download.elster.de/download/eric/eric_43/ERiC-43.5.4.0-Dokumentation.zip",
      "https://download.elster.de/download/eric/eric_43/ERiC-43.5.4.0-Schemadokumentation.zip"
    ])
  end

  it "builds installation paths for the selected version" do
    expect(installer.downloads_path).to eq(File.join(root, ".eric", "downloads"))
    expect(installer.sdk_home).to eq(File.join(root, ".eric", "ERiC-43.5.4.0", "Linux-x86_64"))
    expect(installer.expected_library).to eq(File.join(installer.sdk_home, "lib", "libericapi.so"))
  end

  it "extracts cached artifacts and leaves an idempotent completed installation" do
    FileUtils.mkdir_p(installer.downloads_path)
    write_zip(
      File.join(installer.downloads_path, "ERiC-#{version}-Linux-x86_64.jar"),
      "ERiC-#{version}/Linux-x86_64/lib/libericapi.so" => "fixture library"
    )
    write_zip(
      File.join(installer.downloads_path, "ERiC-#{version}-Dokumentation.zip"),
      "ERiC-#{version}/Dokumentation/readme.html" => "fixture docs"
    )
    write_zip(
      File.join(installer.downloads_path, "ERiC-#{version}-Schemadokumentation.zip"),
      "ERiC-#{version}/Schemadokumentation/schema.html" => "fixture schema"
    )

    expect(installer).not_to receive(:download)
    expect(installer.install).to eq(installer.sdk_home)
    expect(File.read(installer.expected_library)).to eq("fixture library")
    expect(File.read(File.join(root, ".eric", "ERiC-#{version}", "Dokumentation", "readme.html"))).to eq("fixture docs")
    expect(File.read(File.join(root, ".eric", "ERiC-#{version}", "Schemadokumentation", "schema.html"))).to eq("fixture schema")

    File.write(installer.expected_library, "keep existing installation")
    expect(installer.install).to eq(installer.sdk_home)
    expect(File.read(installer.expected_library)).to eq("keep existing installation")
  end

  it "reports invalid ZIP archives clearly" do
    path = File.join(root, "broken.zip")
    File.write(path, "not a zip")

    expect { installer.extract(path) }
      .to raise_error(described_class::InstallError, /invalid archive .*broken\.zip/)
  end

  def write_zip(path, entries)
    Zip::File.open(path, create: true) do |zip|
      entries.each do |name, contents|
        zip.get_output_stream(name) { |stream| stream.write(contents) }
      end
    end
  end
end
