semver
======

Semantic Versioning Library

## Implementation

This library parses, validates and compares version numbers and version ranges.

It uses the following formats:
* Semantic Versioning 2.0.0 - http://semver.org
* Semantic Versioning Range - https://github.com/isaacs/node-semver

## Usage

    auto version = SemVer("1.0.0");
    assert(version.isValid);
    assert(version.isStable);

    auto version = SemVer("1.0.0-rc.1");
    assert(version.isValid);
    assert(!version.isStable);

    assert(SemVer("1.0.0") > SemVer("1.0.0+build.1"));
    assert(SemVer("1.0.0").differAt(SemVer("1.0.0+build.1")) == VersionPart.BUILD);

    auto versionRange = SemVerRange(">=1.0.0");
    assert(versionRange.isValid);

    assert(SemVer("1.0.1").satisfies(version));
    assert(SemVer("1.1.0").satisfies(version));

    auto semVers = [SemVer("1.1.0"), SemVer("1.0.0"), SemVer("0.8.0")];
    assert(semVers.maxSatisfying(SemVerRange("<=1.0.0")) == SemVer("1.0.0"));
    assert(semVers.maxSatisfying(SemVerRange(">=1.0")) == SemVer("1.1.0"));

    semVers = [SemVer("1.0.0+build.3"), SemVer("1.0.0+build.1"), SemVer("1.1.0")];
    assert(semVers.maxSatisfying(SemVerRange("<=1.0.0")) == SemVer("1.0.0+build.3"));
    assert(semVers.maxSatisfying(SemVerRange(">=1.0")) == SemVer("1.1.0"));
