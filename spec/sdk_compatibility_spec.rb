require "open3"
require "rbconfig"
require "shellwords"
require "tmpdir"
require "ffi"
require "logger"
require "liberic/sdk/configuration"
require "liberic/sdk/fehlercodes"
require "liberic/sdk/types"

RSpec.describe "installed ERIC SDK compatibility" do
  let(:root) { File.expand_path("..", __dir__) }
  let(:version) { Liberic::SDK::Configuration::LIBERICAPI_VERSION.last }
  let(:sdk_home) do
    ENV["ERIC_HOME"] || File.join(root, ".eric", "ERiC-#{version}", "Linux-x86_64")
  end
  let(:include_path) { File.join(sdk_home, "include") }

  before do
    skip "install ERIC #{version} with `bundle exec rake eric:install`" unless File.directory?(include_path)
  end

  it "loads every bound symbol and reports the supported runtime version" do
    script = <<~RUBY
      require "liberic"
      xml = Liberic::Helpers::Invocation.with_result_buffer { |handle| Liberic::SDK::API.version(handle) }
      version = Liberic::Response::Version.new(xml).for_library("libericapi")
      abort "EricSystemCheck failed" unless Liberic::SDK::API.system_check == 0
      print version
    RUBY
    stdout, stderr, status = Open3.capture3(
      { "ERIC_HOME" => sdk_home, "ERIC_HOME_40" => nil },
      RbConfig.ruby,
      "-I#{File.join(root, "lib")}",
      "-e",
      script,
      chdir: root
    )

    expect(status).to be_success, stderr
    expect(stdout).to eq(version)
    expect(stderr).not_to include("required, but")
  end

  it "checks and validates an example tax filing through Liberic::Process" do
    example = Dir[File.join(sdk_home, "Beispiel", "ericdemo-java", "ESt_20*.xml")].max
    skip "the installed ERIC SDK does not include an example income tax filing" unless example

    script = <<~RUBY
      require "liberic"
      filing = Liberic::Process.new(File.binread(ARGV.fetch(0)), ARGV.fetch(1))
      abort "EricCheckXML returned errors" unless filing.check.empty?
      result = filing.execute
      abort "EricBearbeiteVorgang returned errors" unless result.values.all?(&:empty?)
    RUBY
    stdout, stderr, status = Open3.capture3(
      { "ERIC_HOME" => sdk_home, "ERIC_HOME_40" => nil },
      RbConfig.ruby,
      "-I#{File.join(root, "lib")}",
      "-e",
      script,
      example,
      File.basename(example, ".xml"),
      chdir: root
    )

    expect(status).to be_success, stderr
    expect(stdout).to be_empty
  end

  it "maps every error code declared by the installed SDK" do
    header = File.binread(File.join(include_path, "eric_fehlercodes.h"))
    declared_codes = header.scan(/^\s*(ERIC_[A-Z0-9_]+)\s*=\s*(-?\d+)/).to_h
    mapped_codes = Liberic::SDK::Fehlercodes::CODES.transform_values(&:to_s).invert.transform_values(&:to_s)

    expect(mapped_codes).to include(declared_codes)
  end

  it "matches the installed SDK's native struct layouts" do
    compiler = Shellwords.split(RbConfig::CONFIG.fetch("CC"))
    skip "a C compiler is required to verify ERIC struct layouts" unless system(*compiler, "--version", out: File::NULL, err: File::NULL)

    Dir.mktmpdir("liberic-layout") do |directory|
      executable = File.join(directory, "layout")
      source = <<~C
        #include <stddef.h>
        #include <stdio.h>
        #include "eric_types.h"

        int main(void) {
          printf("druck:%zu:%zu:%zu:%zu:%zu:%zu:%zu:%zu\\n",
            sizeof(eric_druck_parameter_t),
            offsetof(eric_druck_parameter_t, version),
            offsetof(eric_druck_parameter_t, vorschau),
            offsetof(eric_druck_parameter_t, duplexDruck),
            offsetof(eric_druck_parameter_t, pdfName),
            offsetof(eric_druck_parameter_t, fussText),
            offsetof(eric_druck_parameter_t, pdfCallback),
            offsetof(eric_druck_parameter_t, pdfCallbackBenutzerdaten));
          printf("crypto:%zu:%zu:%zu:%zu\\n",
            sizeof(eric_verschluesselungs_parameter_t),
            offsetof(eric_verschluesselungs_parameter_t, version),
            offsetof(eric_verschluesselungs_parameter_t, zertifikatHandle),
            offsetof(eric_verschluesselungs_parameter_t, pin));
          return 0;
        }
      C
      _, compile_error, compile_status = Open3.capture3(
        *compiler,
        "-I#{include_path}",
        "-x",
        "c",
        "-o",
        executable,
        "-",
        stdin_data: source
      )
      expect(compile_status).to be_success, compile_error

      output, run_error, run_status = Open3.capture3(executable)
      expect(run_status).to be_success, run_error

      expect(native_layout(output, "druck")).to eq(ffi_layout(Liberic::SDK::Types::DruckParameter))
      expect(native_layout(output, "crypto")).to eq(ffi_layout(Liberic::SDK::Types::VerschluesselungsParameter))
    end
  end

  def native_layout(output, name)
    output.lines.find { |line| line.start_with?("#{name}:") }.strip.split(":").drop(1).map(&:to_i)
  end

  def ffi_layout(struct)
    [struct.size, *struct.members.map { |member| struct.offset_of(member) }]
  end
end
