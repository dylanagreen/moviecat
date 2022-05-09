# moviecat
Lightweight intelligent desktop movie ranking program!

Moviecat uses a binary search version of insertion sort to insert movies into your
personal movie list. The program will ask you a series of direct comparison questions
where you must compare the movie to another movie in your personal list. After
a set amount of questions the program will insert that movie into the found position
in your movie list. An example of this in operation is below.

This program will organically build a ranking of every movie you've seen without
the requirement for scales. You are freed from having to rate movies on arbitrary
scales, like 0-10, or out of 5 stars, or the number of times you'd rather watch
Casablanca as compared to each movie. Things like that.

## Dependencies
Moviecat should compile just fine without any dependencies, although if you want
to actually run it you'll need sqlite.

Upon first startup moviecat will download imdb datasets from https://datasets.imdbws.com.
It will download `title.basics.tsv.gz`, `title.crew.tsv.gz` and `name.basics.tsv.gz`
When self-updating, moviecat will redownload the datasets to update its internal
database. By default this happens if the last update happened more than 4 weeks
ago.

## Compiling moviecat

To compile moviecat run the following:
```
nim c src/moviecat.nim
```

For a quicker, but potentially more unstable version you can turn on the `-d:release` or
`-d:danger` flags. Release binaries are compiled using `-d:release`.

moviecat requires Nim >= 1.4.2 as it requires db_sqlite procs that were not added until that version.

# Example
I have chosen to rank Lady Bird (2017) among a few random classics, since I thought
of this program while watching Lady Bird.
```
What would you like to do?
rank lady bird
Found these movies:
[0] (tt0163050) The Legend of a Lady Bird, 1997
[1] (tt1442194) A Life: The Story of Lady Bird Johnson, 1992
[2] (tt4925292) Lady Bird, 2017
[3] (tt7713508) The Stalker of Lady Bird Lake Part IV: A Location Scouting Film, 2017
Which movie did you want?
2
You have selected (tt4925292) Lady Bird, 2017
Is (tt4925292) Lady Bird, 2017 > (tt0087469) Indiana Jones and the Temple of Doom, 1984?
yes
Is (tt4925292) Lady Bird, 2017 > (tt0062622) 2001: A Space Odyssey, 1968?
yes
Is (tt4925292) Lady Bird, 2017 > (tt0088763) Back to the Future, 1985?
no
What date did you watch this movie? (YYYY-MM-DD)
Input "N" to skip.
2020-06-27
Inserting at rank 2
What would you like to do?
print
[1] (tt0088763) Back to the Future, 1985
[2] (tt4925292) Lady Bird, 2017 (Watched on 2020-06-27)
[3] (tt0062622) 2001: A Space Odyssey, 1968
[4] (tt0082971) Raiders of the Lost Ark, 1981 (Watched on 2020-05-04)
[5] (tt0087469) Indiana Jones and the Temple of Doom, 1984 (Watched on 2020-05-05)
[6] (tt0099088) Back to the Future Part III, 1990
[7] (tt0096874) Back to the Future Part II, 1989
```
