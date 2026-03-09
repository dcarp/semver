# semver

Semantic Versioning and Minimal Version Selection Library

## Implementation

This library parses, validates and compares version numbers and version ranges,
and resolves dependency graphs using Minimal Version Selection.

It uses the following formats:

- Semantic Versioning 2.0.0 - http://semver.org
- Semantic Versioning Range - https://github.com/isaacs/node-semver
- Minimal Version Selection - https://research.swtch.com/vgo-mvs

## Usage

```D
import semver;
import mvs;

auto version1 = SemVer("1.0.0");
assert(version1.isValid);
assert(version1.isStable);

auto version2 = SemVer("1.0.0-rc.1");
assert(version2.isValid);
assert(!version2.isStable);

auto version3 = SemVer("1.2.3-rc.42");
assert(version3.major == 1);
assert(version3.minor == 2);
assert(version3.patch == 3);

assert(SemVer("1.0.0") > SemVer("1.0.0+build.1"));
assert(SemVer("1.0.0").differAt(SemVer("1.0.0+build.1")) == VersionPart.BUILD);

auto versionRange = SemVerRange(">=1.0.0");
assert(versionRange.isValid);

assert(SemVer("1.0.1").satisfies(versionRange));
assert(SemVer("1.1.0").satisfies(versionRange));

auto semVers = [SemVer("1.1.0"), SemVer("1.0.0"), SemVer("0.8.0")];
assert(semVers.maxSatisfying(SemVerRange("<=1.0.0")) == SemVer("1.0.0"));
assert(semVers.maxSatisfying(SemVerRange(">=1.0")) == SemVer("1.1.0"));
assert(semVers.minSatisfying(SemVerRange(">=1.0")) == SemVer("1.0.0"));
assert(semVers.minSatisfying(SemVerRange("<=0.8.0")) == SemVer("0.8.0"));

semVers = [SemVer("1.0.0+build.3"), SemVer("1.0.0+build.1"), SemVer("1.1.0")];
assert(semVers.maxSatisfying(SemVerRange("<=1.0.0")) == SemVer("1.0.0+build.3"));
assert(semVers.maxSatisfying(SemVerRange(">=1.0")) == SemVer("1.1.0"));

auto roots = [
    "A": SemVerRange(">=1.0.0"),
    "C": SemVerRange(">=1.2.0"),
];

auto available = [
    "A": [SemVer("1.0.0"), SemVer("1.1.0"), SemVer("2.0.0")],
    "B": [SemVer("1.0.0"), SemVer("1.1.0"), SemVer("2.0.0")],
    "C": [SemVer("1.0.0"), SemVer("1.2.0")],
];

auto dependencies = [
    ModuleVersion("A", SemVer("1.0.0")): ["B": SemVerRange(">=1.0.0")],
    ModuleVersion("A", SemVer("1.1.0")): ["B": SemVerRange(">=1.1.0")],
    ModuleVersion("A", SemVer("2.0.0")): ["B": SemVerRange(">=2.0.0")],
    ModuleVersion("B", SemVer("1.0.0")): ["C": SemVerRange(">=1.0.0")],
    ModuleVersion("B", SemVer("1.1.0")): ["C": SemVerRange(">=1.2.0")],
    ModuleVersion("B", SemVer("2.0.0")): ["C": SemVerRange(">=1.2.0")],
];

auto selected = minimalVersionSelection(roots, available, dependencies);
assert(selected["A"] == SemVer("1.0.0"));
assert(selected["B"] == SemVer("1.0.0"));
assert(selected["C"] == SemVer("1.2.0"));
```
