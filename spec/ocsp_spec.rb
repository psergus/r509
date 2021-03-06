require 'spec_helper'
require 'r509/ocsp'
require 'openssl'

describe R509::OCSP::Response do
  before :all do
    @ocsp_test_cert = TestFixtures::OCSP_TEST_CERT
    @test_ca_config = TestFixtures.test_ca_config
    @test_ca_ocsp_response = TestFixtures::TEST_CA_OCSP_RESPONSE
    @test_ca_subroot_ocsp_response = TestFixtures::TEST_CA_SUBROOT_OCSP_RESPONSE
    @ocsp_response_der = TestFixtures::STCA_OCSP_RESPONSE
    @stca_cert = TestFixtures::STCA_CERT
  end
  it "raises an exception if you try to pass the wrong type to the constructor" do
    expect { R509::OCSP::Response.new(@ocsp_response_der) }.to raise_error(R509::R509Error, 'You must pass an OpenSSL::OCSP::Response object to the constructor. See R509::OCSP::Response.parse if you are trying to parse')
  end
  it "raises an exception if you pass nil to #parse" do
    expect { R509::OCSP::Response.parse(nil) }.to raise_error(R509::R509Error, 'You must pass a DER encoded OCSP response to this method')
  end
  it "parses a response der and returns the right object on #parse" do
    ocsp_response = R509::OCSP::Response.parse(@ocsp_response_der)
    expect(ocsp_response.is_a?(R509::OCSP::Response)).to eq(true)
    expect(ocsp_response.status).to eq(OpenSSL::OCSP::RESPONSE_STATUS_SUCCESSFUL)
  end
  it "returns data on to_der" do
    ocsp_response = R509::OCSP::Response.parse(@ocsp_response_der)
    expect(ocsp_response.to_der).not_to be_nil
  end
  it "returns a BasicResponse object on #basic" do
    ocsp_response = R509::OCSP::Response.parse(@ocsp_response_der)
    expect(ocsp_response.basic.is_a?(OpenSSL::OCSP::BasicResponse)).to eq(true)
  end
  it "returns true if response verifies (in validity period, chain builds to trusted root that's provided)" do
    ocsp_response = R509::OCSP::Response.parse(@test_ca_ocsp_response)
    expect(ocsp_response.verify(TestFixtures.test_ca_config.ca_cert.cert)).to eq(true)
  end
  it "verify supports an single certificate and uses it to validate" do
    ocsp_response = R509::OCSP::Response.parse(@test_ca_ocsp_response)
    expect(ocsp_response.verify(TestFixtures.test_ca_config.ca_cert.cert)).to eq(true)
  end
  it "verify supports an array of certificates and uses all of them to validate a chain" do
    ocsp_response = R509::OCSP::Response.parse(@test_ca_subroot_ocsp_response)
    expect(ocsp_response.verify([TestFixtures.test_ca_config.ca_cert.cert, TestFixtures.test_ca_subroot_cert.cert])).to eq(true)
  end
  it "verify returns false if you don't give it enough certs to build a chain to a trusted root" do
    ocsp_response = R509::OCSP::Response.parse(@test_ca_subroot_ocsp_response)
    expect(ocsp_response.verify([TestFixtures.test_ca_config.ca_cert.cert])).to eq(false)
  end
  it "returns false if response does not verify" do
    # expired response
    ocsp_response = R509::OCSP::Response.parse(@ocsp_response_der)
    expect(ocsp_response.verify(OpenSSL::X509::Certificate.new(@stca_cert))).to eq(false)
  end
  it "nonce is present and equal" do
    ocsp_request = OpenSSL::OCSP::Request.new
    ocsp_request.add_nonce
    basic_response = OpenSSL::OCSP::BasicResponse.new
    basic_response.copy_nonce(ocsp_request)
    response_double = double("ocsp_response")
    expect(response_double).to receive(:is_a?).and_return('OpenSSL::OCSP::Response')
    expect(response_double).to receive(:basic).and_return(basic_response)
    ocsp_response = R509::OCSP::Response.new(response_double)
    expect(ocsp_response.check_nonce(ocsp_request)).to eq(R509::OCSP::Request::Nonce::PRESENT_AND_EQUAL)
  end
  it "no nonce" do
    ocsp_request = OpenSSL::OCSP::Request.new
    basic_response = OpenSSL::OCSP::BasicResponse.new
    basic_response.copy_nonce(ocsp_request)
    response_double = double("ocsp_response")
    expect(response_double).to receive(:is_a?).and_return('OpenSSL::OCSP::Response')
    expect(response_double).to receive(:basic).and_return(basic_response)
    ocsp_response = R509::OCSP::Response.new(response_double)
    expect(ocsp_response.check_nonce(ocsp_request)).to eq(R509::OCSP::Request::Nonce::BOTH_ABSENT)
  end
  it "has a nonce in the response only" do
    ocsp_request = OpenSSL::OCSP::Request.new
    nonce_request = OpenSSL::OCSP::Request.new
    nonce_request.add_nonce
    basic_response = OpenSSL::OCSP::BasicResponse.new
    basic_response.copy_nonce(nonce_request)
    response_double = double("ocsp_response")
    expect(response_double).to receive(:is_a?).and_return('OpenSSL::OCSP::Response')
    expect(response_double).to receive(:basic).and_return(basic_response)
    ocsp_response = R509::OCSP::Response.new(response_double)
    expect(ocsp_response.check_nonce(ocsp_request)).to eq(R509::OCSP::Request::Nonce::RESPONSE_ONLY)
  end
  it "nonce in request and response is not equal" do
    ocsp_request = OpenSSL::OCSP::Request.new
    ocsp_request.add_nonce
    second_request = OpenSSL::OCSP::Request.new
    second_request.add_nonce
    basic_response = OpenSSL::OCSP::BasicResponse.new
    basic_response.copy_nonce(ocsp_request)
    response_double = double("ocsp_response")
    expect(response_double).to receive(:is_a?).and_return('OpenSSL::OCSP::Response')
    expect(response_double).to receive(:basic).and_return(basic_response)
    ocsp_response = R509::OCSP::Response.new(response_double)
    expect(ocsp_response.check_nonce(second_request)).to eq(R509::OCSP::Request::Nonce::NOT_EQUAL)
  end
  it "nonce in request only" do
    ocsp_request = OpenSSL::OCSP::Request.new
    ocsp_request.add_nonce
    basic_response = OpenSSL::OCSP::BasicResponse.new
    response_double = double("ocsp_response")
    expect(response_double).to receive(:is_a?).and_return('OpenSSL::OCSP::Response')
    expect(response_double).to receive(:basic).and_return(basic_response)
    ocsp_response = R509::OCSP::Response.new(response_double)
    expect(ocsp_response.check_nonce(ocsp_request)).to eq(R509::OCSP::Request::Nonce::REQUEST_ONLY)
  end

end
