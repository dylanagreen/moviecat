import unittest

import ../src/options

suite "test options":

  test "year -> true":
    set_option_to_value("year", true)

    # Set up the expected to include year as true.
    var expected: set[SearchOptions]
    expected.incl(SearchOptions.BYYEAR)

    doAssert active_options == expected

  test "year -> true x2":
    # Tests setting the year option to true twice in a row.
    set_option_to_value("year", true)
    set_option_to_value("year", true)

    # Set up the expected to include year as true.
    var expected: set[SearchOptions]
    expected.incl(SearchOptions.BYYEAR)

    doAssert active_options == expected

  test "year -> false x2":
    # Tests setting the year option to false twice in a row.
    set_option_to_value("year", false)
    set_option_to_value("year", false)

    # Set up the expected to include year as false.
    var expected: set[SearchOptions]

    doAssert active_options == expected

  test "year -> true -> false":
    # Tests setting the year option to true then back to false.
    set_option_to_value("year", true)

    # Set up the expected to include year as true.
    var expected: set[SearchOptions]
    expected.incl(SearchOptions.BYYEAR)
    doAssert active_options == expected

    # Now set back to false.
    set_option_to_value("year", false)

    expected.excl(SearchOptions.BYYEAR)
    doAssert active_options == expected

  test "year, director -> true":
    set_option_to_value("year", true)
    set_option_to_value("director", true)

    # Set up the expected to include year as true.
    var expected: set[SearchOptions]
    expected.incl(SearchOptions.BYYEAR)
    expected.incl(SearchOptions.BYDIRECTOR)

    doAssert active_options == expected
