require 'spec_helper'

describe 'Menilite::Model' do
  it 'can define field' do
    class M1 < Menilite::Model
      field :f1
    end

    expect(M1.method_defined?('f1')).to eq(true)
  end

  it 'raise type error on constructor' do
    class M1 < Menilite::Model
      field :f1
    end

    expect{ M1.new(f2: 'test') }.to raise_error(ArgumentError)
  end
end
