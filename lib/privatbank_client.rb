require 'nokogiri'
require 'json'
require 'csv'
require 'date'
require 'net/http'

class PrivatbankClient

  API_URL = 'https://api.privatbank.ua/p24api/rest_fiz'

  STATEMENT_FIELDS = {
    card: :card,
    appcode: :appcode,
    date: :trandate,
    time: :trantime,
    amount: :amount,
    card_amount: :cardamount,
    rest: :rest,
    terminal: :terminal,
    description: :description
  }

  def initialize(settings)
    @settings = settings
  end

  def vipiska_csv
    request_body = build_request
    xml = send_request(request_body)

    if error = xml.at_css('error')
      error[:message]
    else
      CSV.generate {|csv|
        xml.css('statement').each do |xml_statement|
          statement = {}
          STATEMENT_FIELDS.each{|key,xml_key| statement[key] = xml_statement[xml_key]}
          statement[:datetime] = statement[:date] + ' ' + statement[:time]
          statement[:amount_in_currency], statement[:currency] = statement[:amount].split(' ')
          statement[:amount], statement[:card_currency] = statement[:card_amount].split(' ')
          statement[:memo] = statement[:description]
          if statement[:card_currency] != statement[:currency]
            rate = (statement[:amount].to_f/statement[:amount_in_currency].to_f).abs
            statement[:memo] = "(#{statement[:amount_in_currency]} #{statement[:currency]}, rate=#{"%0.2f" % rate}) " + statement[:memo]
          end
          csv << [
            statement[:datetime],
            statement[:amount],
            statement[:terminal],
            statement[:memo],
          ]
        end
      }
    end
  end

  private

  def build_request
    start_date_str, end_date_str = [Date.today-31, Date.today].map{|d| d.strftime("%d.%m.%Y") }

    request_builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.request {
        xml.merchant {
          xml.id_ @settings[:merchant_id]
          xml.signature
        }
        xml.data {
          xml.oper "cmt"
          xml.wait 0
          xml.test 1
          xml.payment(id: '') {
            xml.prop(name: 'sd', value: start_date_str)
            xml.prop(name: 'ed', value: end_date_str)
            xml.prop(name: 'card', value: @settings[:card])
          }
        }
      }
    end

    # sign
    data_str = request_builder.doc.at_css('data').children.map{|c| to_compact_xml(c)}.join('')
    signature = Digest::SHA1.hexdigest(Digest::MD5.hexdigest(data_str+@settings[:password]))
    request_builder.doc.at_css('signature').content = signature

    to_compact_xml(request_builder)
  end

  def send_request(request_body)
    uri = URI(API_URL)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Post.new uri
      request.body = request_body
      http.request request
    end

    xml = Nokogiri::XML(response.body)
  end

  def to_compact_xml(xml_object)
    xml_object.to_xml(indent_text: '').gsub("\n", "")
  end
end
