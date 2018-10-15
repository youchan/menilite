require "opal/unit_test"
require "menilite"

class ModelTest < Opal::UnitTest::TestCase
  test 'Model can define field' do
    class M1 < Menilite::Model
      field :f1
    end

    assert(M1.method_defined?('f1'))
  end

  test 'Constructor raises when a field name is not found' do
    class M1 < Menilite::Model
      field :f1
    end

    assert_raises(ArgumentError) do
      M1.new(f2: 'test')
    end
  end

  test 'Constructo raises type error when field type missmatch' do
    class M1 < Menilite::Model
      field :f1
    end

    assert_raises(Menilite::TypeError) do
      M1.new(f1: 1)
    end
  end

  test 'Field is defined as enum type' do
    class M2 < Menilite::Model
      field :f1, enum: [:e1, :e2]
    end

    m2 = M2.new(f1: :e1)
    assert_equals(:e1, m2.f1)
  end

  test 'validation for enum type' do
    class M2 < Menilite::Model
      field :f1, enum: [:e1, :e2]
    end

    assert_raises(Menilite::TypeError) do
      M2.new(f1: :e3)
    end
  end

  test 'Enum value should be converted to int value' do
    class M2 < Menilite::Model
      field :f1, enum: [:e1, :e2]
    end

    m2 = M2.new(f1: :e2)
    assert_equals(1, m2.fields[:f1])
  end
end
