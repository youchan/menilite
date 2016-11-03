require 'spec_helper'

describe 'Menilite::Model' do
  it 'can define field' do
    class M1 < Menilite::Model
      field :f1
    end

    expect(M1.method_defined?('f1')).to eq(true)
  end

  it 'raise field not found error on constructor' do
    class M1 < Menilite::Model
      field :f1
    end

    expect{ M1.new(f2: 'test') }.to raise_error(ArgumentError)
  end

  it 'raise type error on constructor' do
    class M1 < Menilite::Model
      field :f1
    end

    expect{ M1.new(f1: 1) }.to raise_error(Menilite::TypeError)
  end

  it 'can define field as enum type' do
    class M2 < Menilite::Model
      field :f1, enum: [:e1, :e2]
    end

    m2 = M2.new(f1: :e1)
    expect(m2.f1).to eq(:e1)
  end

  it 'validate enum type' do
    class M2 < Menilite::Model
      field :f1, enum: [:e1, :e2]
    end

    expect{ M2.new(f1: :e3) }.to raise_error(Menilite::TypeError)
  end

  it 'shold convert int value for enum type value' do
    class M2 < Menilite::Model
      field :f1, enum: [:e1, :e2]
    end

    m2 = M2.new(f1: :e2)
    expect(m2.fields[:f1]).to eq(1)
  end
end
