require "open3"
require "rbconfig"

RSpec.describe "ERiC home configuration" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:command) do
    [RbConfig.ruby, "-I#{File.join(root, "lib")}", "-e", "require 'liberic/boot'; print Liberic.eric_home"]
  end

  it "prefers ERIC_HOME over ERIC_HOME_40" do
    stdout, stderr, status = Open3.capture3(
      { "ERIC_HOME" => "/preferred", "ERIC_HOME_40" => "/legacy" },
      *command,
      chdir: root
    )

    expect(status).to be_success, stderr
    expect(stdout).to eq("/preferred")
  end

  it "falls back to ERIC_HOME_40" do
    stdout, stderr, status = Open3.capture3(
      { "ERIC_HOME" => nil, "ERIC_HOME_40" => "/legacy" },
      *command,
      chdir: root
    )

    expect(status).to be_success, stderr
    expect(stdout).to eq("/legacy")
  end
end
