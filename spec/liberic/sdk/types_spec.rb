require "ffi"
require "logger"
require "liberic/sdk/types"

RSpec.describe Liberic::SDK::Types do
  describe Liberic::SDK::Types::DruckParameter do
    it "matches the ERIC version-4 print parameter fields" do
      expect(described_class.members).to eq([
        :version,
        :vorschau,
        :duplexDruck,
        :pdfName,
        :fussText,
        :pdfCallback,
        :pdfCallbackBenutzerdaten
      ])
    end
  end

  it "defines the ERIC processing flags" do
    flags = described_class::BearbeitungFlag

    expect(flags[:validiere]).to eq(1 << 1)
    expect(flags[:sende]).to eq(1 << 2)
    expect(flags[:drucke]).to eq(1 << 5)
    expect(flags[:pruefe_hinweise]).to eq(1 << 7)
    expect(flags[:validiere_ohne_freigabedatum]).to eq(1 << 8)
  end
end
