require "test_helper"

describe Object do
  describe "#track!" do
    it "identity option sets identity" do
      metric "Coolness"
      new_ab_test :foobar do
        alternatives "foo", "bar"
        metrics :coolness
      end
      track!(:coolness, :identity=>'quux')

      assert_equal 1, experiment(:foobar).alternatives.sum(&:conversions)
    end

    it "accepts value for conversion" do
      metric "Coolness"
      new_ab_test :foobar do
        alternatives "foo", "bar"
        metrics :coolness
      end
      track!(:coolness, :identity=>'quux', :values=>[2])

      assert_equal 2, experiment(:foobar).alternatives.sum(&:conversions)
    end
  end
<<<<<<< HEAD
end
=======

  # TODO: Get this to run locally
  # describe "#saw_variation_for_experiment" do
  #   it "saw variation returns" do
  #     metric "Coolness"
  #     new_ab_test :foobar do
  #       alternatives "foo", "bar"
  #       metrics :coolness
  #     end
  #
  #     result = saw_variation_for_experiment(:foobar)
  #     assert !result
  #
  #     ab_test :foobar
  #     result = saw_variation_for_experiment(:foobar)
  #     assert result
  #   end
  # end
end
>>>>>>> added saw_variation_for_experiment method
