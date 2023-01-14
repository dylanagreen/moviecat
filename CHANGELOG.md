# Changelog

This the log of changes to [moviecat](https://github.com/dylanagreen/moviecat).

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - Devon Rex - Unreleased
### Added
- moviecat now no longer requires the user to provide IMDB dataset files.
  - Upon initial startup moviecat will download the necessary files and initialize the internal database
  - Files are redownloaded every 4 weeks by default to self-update the databse. This frequency can be changed in the `options` menu
- New `export` command (alias `csv`). `export` will export a barebones [letterboxd](https://letterboxd.com/) compatible CSV file.
   - If there is already a letterboxd csv present, moviecat will also save a `letterboxd_update.csv` which includes all films that were ranked since the prior `letterboxd.csv` was saved.
- New `update` command. `update` will manually request and force a database update.
- Ranking now displays the number of questions beside each question.

### Changed
- `options` now includes the download cadence.
  - Under the hood this required changing the method by which the options are saved from marshalling to saving per line. This has no CLI effect.

### Fixed
- Fixed a crash when `stats` was passed a keyword but no keyword descriptor (i.e. `stats watched` without a year)


## [0.3.0] - Aegean - 2022-02-04
### Added
- New `stats` command. `stats` can be used with a variety of sub commands:
  - `stats year all` will show stats for how many movies were watched per year
  - `stats all` will print global statistics
  - `stats [writer/director] [name]` will display your representative statistics for the requested writer or director
  - `stats [year/watched] [year number]` will display representative stats for movies either released in a given year or watched in a given year, respectively.
- `watched` keyword added for `print` command refinement

### Changed
- Options are now maintained internally as an enum



## [0.2.0] - Bengal - 2021-02-16
### Added

### Changed
- `find` and `rank` commands can now be refined using movie writers and directors in addition to release year (as before).
  - writer's and director's names are required to be in quotation marks to search correctly
- `print` can be refined by writers and directors

### Fixed
- Fixed a bug where turning off refinement options did not save correctly.

## [0.1.1] - 2020-12-27
### Changed
- Cancelling now allowed when selecting a movie to rank

### Fixed
- Fixed a bug when quitting after passing invalid movie choices
- Fixed a crash when trying to serach for movie titles containing special characters (?_%')

## [0.1.0] - Calico - 2020-12-24
Initial release.