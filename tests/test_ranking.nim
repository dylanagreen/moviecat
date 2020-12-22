import unittest

import ../src/ranking

suite "binary search":
  # Running three tests (middle, top and bottom) for 2 and 3 entries should
  # cover all possible cases, since it's an even and an odd number of starting
  # entries. All other cases can be reduced to combinations of these.
  # for ex, with 4 entries, the first answer will reduce it to a two entry case
  # for 5 entries, the first answer will reduce it to either a three  or two
  # entry case depending on what the answer is.
  # For two entries the lower is 0 and the upper is 1 (num_ranked - 1)
  test "index at middle, 2 entries":
    # To get at the top we answer yes first, then no second.
    # i.e. better than bottom movie but worse than top movie.
    var i = 0
    let answers = @[true, false]
    proc comp(movie: string, rank: int): bool =
      result = answers[i]
      i += 1
    let
      observed = get_movie_rank(0, 1, "test", comp)

      # Expect it at 1 because we move the movies up a rank
      # So movies are in pos 1 & 2, but movie 2 (better) will get bumped to pos 3
      expected = 1
    doAssert observed == expected

  test "index at top, 2 entries":
    # To get at the top we answer yes at all steps.
    var i = 0
    let answers = @[true, true, true]
    proc comp(movie: string, rank: int): bool =
      result = answers[i]
      i += 1
    let
      observed = get_movie_rank(0, 1, "test", comp)

      # Expect at 3 since movies are at pos 1 and 2
      expected = 2
    doAssert observed == expected

  test "index at bottom, 2 entries":
    # To get at the bottom we answer yes at all steps.
    var i = 0
    let answers = @[false, false, false]
    proc comp(movie: string, rank: int): bool =
      result = answers[i]
      i += 1
    let
      observed = get_movie_rank(0, 2, "test", comp)

      # Expect at 0 since movies are at pos 1 and 2
      expected = 0
    doAssert observed == expected

  # For 3 entries low is 0 and high is 2 (remember high = num - 1)
  # Again, because algorithm is 0 indexed and ranking is 1 indexed.
  test "index at middle, 3 entries (true, false)":
    # To get at the top we answer yes first, then no second.
    # i.e. better than bottom movie but worse than top movie.
    var i = 0
    let answers = @[true, false]
    proc comp(movie: string, rank: int): bool =
      result = answers[i]
      i += 1
    let
      observed = get_movie_rank(0, 2, "test", comp)

      # Expect it at 2 because we move the movies up a rank
      # Also this number is 0 index but ranking is 1 indexed
      # So movies are in pos 1, 2, 3, but movie 3 (better) will get bumped to pos 4
      expected = 2
    doAssert observed == expected

  test "index at middle, 3 entries (false, true)":
    # To get at the top we answer yes first, then no second.
    # i.e. better than bottom movie but worse than top movie.
    var i = 0
    let answers = @[false, true]
    proc comp(movie: string, rank: int): bool =
      result = answers[i]
      i += 1
    let
      observed = get_movie_rank(0, 2, "test", comp)

      # Expect it at 1 because we move the movies up a rank
      # So movies are in pos 1, 2, 3, but movie 1 (better) will get bumped to pos 2
      expected = 1
    doAssert observed == expected

  test "index at top, 3 entries":
    # To get at the top we answer yes at all steps.
    var i = 0
    let answers = @[true, true, true]
    proc comp(movie: string, rank: int): bool =
      result = answers[i]
      i += 1
    let
      observed = get_movie_rank(0, 2, "test", comp)

      # Expect at 3 since movies are at pos 1, 2, 3
      expected = 3
    doAssert observed == expected

  test "index at bottom, 3 entries":
    # To get at the bottom we answer yes at all steps.
    var i = 0
    let answers = @[false, false, false]
    proc comp(movie: string, rank: int): bool =
      result = answers[i]
      i += 1
    let
      observed = get_movie_rank(0, 2, "test", comp)

      # Expect at 0 since movies are at pos 1, 2, 3
      expected = 0
    doAssert observed == expected