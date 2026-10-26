class Country
  class Unsupported < ArgumentError; end
  ALL = [
    { name: "India", currency: "INR" },
    { name: "USA", currency: "USD" },
    { name: "Canada", currency: "CAD" }
  ].map(&:freeze).freeze
  NAMES = ALL.map { |country| country[:name] }.freeze
  def self.all = ALL
  def self.names = NAMES
  def self.currency_for(name)
    ALL.find { |country| country[:name] == name }&.fetch(:currency) ||
      raise(Unsupported, name)
  end
end
