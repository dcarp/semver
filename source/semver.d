/**
 * License: <a href="http://opensource.org/licenses/MIT">MIT</a>.
 * Authors: Dragos Carp
 *
 * See_Also: 
 *    http://semver.org, https://github.com/isaacs/node-semver
 */

module semver;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.range;
import std.regex;
import std.stdio;
import std.string;

/**
 * The version part of a version number.
 */
enum VersionPart
{
    MAJOR,      // major number
    MINOR,      // minor number
    PATCH,      // patch number
    PRERELEASE, // prerelease suffix
};

/**
 * Represent a semantic version number MAJOR[.MINOR[.PATH]][-PRERELEASE][+BUILD].
 */
struct SemVer
{
    private uint[3] ids;
    private string[] prerelease;
    private string[] build;

    private bool isValid;

    @disable this();

    /**
     * Creates and validates a version number from a string.
     *
     * If string format is invalid it just sets the $(D valid) property to $(D false).
     */
    this(string semVer)
    {
        isValid = false;
        if (semVer.empty)
            return;
        if (!semVer.skipOver('v'))
            semVer.skipOver('=');

        auto re = regex(`^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([a-zA-Z\d-.]+))?(?:\+([a-zA-Z\d-.]+))?$`);
        auto m = semVer.matchAll(re);
        if (m.empty)
            return;

        foreach (i, ref id; ids)
        {
            if (!m.captures[i+1].empty)
                id = m.captures[i+1].to!uint;
        }

        if (!m.captures[4].empty)
        {
            prerelease = m.captures[4].splitter('.').array;
            if (prerelease.any!empty)
                return;
        }

        if (!m.captures[5].empty)
        {
            build = m.captures[5].splitter('.').array;
            if (build.any!empty)
                return;
        }

        isValid = true;
    }

    /**
     * Return the canonical string format.
     */
    string toString() const
    {
        if (!isValid)
            return "<invalid_semver>";

        string semVer = "%(%s.%)".format(ids);
        if (!prerelease.empty)
            semVer ~= "-" ~ "%-(%s.%)".format(prerelease);
        if (!build.empty)
            semVer ~= "+" ~ "%-(%s.%)".format(build);
        return semVer;
    }

    /**
     * Property that indicates if this is a valid, semantic version.
     */
    @property bool valid() const
    {
        return isValid;
    }

    /**
     * Increment version number.
     */
    SemVer inc(VersionPart versionPart) const
    in
    {
        assert(this.valid);
    }
    out(result)
    {
        assert(result.valid);
    }
    body
    {
        SemVer result = "0";
        foreach (i; 0..versionPart)
            result.ids[i] = this.ids[i];
        if (versionPart != VersionPart.PRERELEASE)
            result.ids[versionPart] = this.ids[versionPart]+1;
        return result;
    }

    package SemVer appendPrerelease0()
    {
        if (prerelease.empty)
            prerelease ~= "0";
        return this;
    }

    unittest
    {
        assert(SemVer("1.2.3").inc(VersionPart.MAJOR) == SemVer("2.0.0"));
        assert(SemVer("1.2.3").inc(VersionPart.MINOR) == SemVer("1.3.0"));
        assert(SemVer("1.2.3-alpha").inc(VersionPart.MINOR) == SemVer("1.3.0"));
        assert(SemVer("1.2.3").inc(VersionPart.PATCH) == SemVer("1.2.4"));
        assert(SemVer("1.2.3-alpha").inc(VersionPart.PATCH) == SemVer("1.2.4"));
        assert(SemVer("1.2.3").inc(VersionPart.PRERELEASE) == SemVer("1.2.3"));
        assert(SemVer("1.2.3-alpha").inc(VersionPart.PRERELEASE) == SemVer("1.2.3"));
    }

    /**
     * Compare this $(LREF SemVer) with the $(D other) $(LREF SemVer).
     *
     * Note that the build information suffixes are ignored.
     */
    int opCmp(ref const SemVer other) const
    in
    {
        assert(this.valid);
        assert(other.valid);
    }
    body
    {
        foreach (i; 0..ids.length)
        {
            if (ids[i] != other.ids[i])
                return ids[i] < other.ids[i] ? -1 : 1;
        }

        if (!prerelease.empty && other.prerelease.empty)
            return -1;
        if (prerelease.empty && !other.prerelease.empty)
            return 1;

        foreach (a, b; lockstep(prerelease, other.prerelease))
        {
            if (a.isNumeric && b.isNumeric)
            {
                if (a.to!uint != b.to!uint)
                    return a.to!uint < b.to!uint ? -1 : 1;
                else
                    continue;
            }
            if (a != b)
                return a < b ? -1 : 1;
        }
        if (prerelease.length != other.prerelease.length)
            return prerelease.length < other.prerelease.length ? -1 : 1;

        return 0;
    }

    /// ditto
    int opCmp(in SemVer other) const
    {
        return this.opCmp(other);
    }

    /**
     * Check for equality between this $(LREF SemVer) and the $(D other)
     *  $(LREF SemVer).
     *
     * Note that the build information suffixes are ignored.
     */
    bool opEquals(ref const SemVer other) const
    {
        return this.opCmp(other) == 0;
    }

    /// ditto
    bool opEquals(in SemVer other) const
    {
        return this.opEquals(other);
    }
}

unittest
{
    assert(!SemVer("1.2-.alpha.32").valid);
    assert(!SemVer("1.2-alpha+").valid);
    assert(!SemVer("1.2-alpha_").valid);
    assert(!SemVer("1.2+32.").valid);
    assert(!SemVer("1.2.5.6").valid);
    assert(!SemVer("").valid);
    assert(SemVer("1.0.0-alpha") < SemVer("1.0.0-alpha.1"));
    assert(SemVer("1.0.0-alpha.1") < SemVer("1.0.0-alpha.beta"));
    assert(SemVer("1.0.0-alpha.beta") < SemVer("1.0.0-beta"));
    assert(SemVer("1.0.0-beta") < SemVer("1.0.0-beta.2"));
    assert(SemVer("1.0.0-beta.2") < SemVer("1.0.0-beta.11"));
    assert(SemVer("1.0.0-beta.11") < SemVer("1.0.0-rc.1"));
    assert(SemVer("1.0.0-rc.1") < SemVer("1.0.0"));
    assert(SemVer("1.0.0-rc.1") == SemVer("1.0.0-rc.1+build.5"));
}

/**
 * Represent a semantic version range.
 *
 * See_Also:
 *    https://github.com/isaacs/node-semver
 */
struct SemVerRange
{
    private struct SimpleRange
    {
        string op;
        SemVer semVer;

        string toString() const
        {
            return op ~ semVer.toString;
        }
    }

    private SimpleRange[][] ranges;

    invariant()
    {
        assert(ranges.all!(r => r.all!(r => ["<", "<=", "=", ">=", ">"].canFind(r.op))));
    }

    private bool isValid;

    @disable this();

    /**
     * Creates and validates a semantic version range from a string.
     *
     * If string format is invalid it just sets the $(D valid) property to $(D false).
     */
    this(string semVerRange)
    {
        isValid = false;
        auto re = regex(`(~|~>|\^|<|<=|=|>=|>)?[v]?(\d+|\*|X|x)(?:\.(\d+|\*|X|x))?(?:\.(\d+|\*|X|x))?([\S]*)`);

        ranges = [SimpleRange[].init];

        while (!semVerRange.stripLeft.empty)
        {
            auto m = semVerRange.matchFirst(re);
            if (m.empty)
                return;

            auto operator = m.captures[1];
            auto wildcard = wildcardAt([m.captures[2], m.captures[3], m.captures[4]]);
            auto expanded = expand([m.captures[2], m.captures[3], m.captures[4], m.captures[5]]);
            if (expanded.empty)
                return;

            auto semVer = SemVer(expanded);
            if (!semVer.valid)
                return;

            switch (m.captures.pre.strip)
            {
                case "":
                    break;
                case "-":
                    if (ranges[$-1].empty || ranges[$-1][$-1].op != "=" ||
                        operator != "" || wildcard != VersionPart.PRERELEASE)
                        return;
                    ranges[$-1][$-1].op = ">=";
                    operator = "<=";
                    break;
                case "||":
                    ranges ~= SimpleRange[].init;
                    break;
                default:
                    return;
            }

            switch (operator)
            {
                case "":
                case "=":
                    final switch (wildcard)
                    {
                        case VersionPart.MAJOR:
                            assert(semVer == SemVer("0.0.0"));
                            ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                            break;
                        case VersionPart.MINOR:
                        case VersionPart.PATCH:
                            ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                            ranges[$-1] ~= SimpleRange("<", semVer.inc(--wildcard).appendPrerelease0);
                            break;
                        case VersionPart.PRERELEASE:
                            ranges[$-1] ~= SimpleRange("=", semVer);
                            break;
                    }
                    break;
                case "<":
                    ranges[$-1] ~= SimpleRange(operator, semVer.appendPrerelease0);
                    break;
                case "<=":
                case ">=":
                case ">":
                    if (wildcard < VersionPart.PRERELEASE)
                        semVer.appendPrerelease0;
                    ranges[$-1] ~= SimpleRange(operator, semVer);
                    break;
                case "~":
                    final switch (wildcard)
                    {
                        case VersionPart.MAJOR:
                            return;
                        case VersionPart.MINOR:
                        case VersionPart.PATCH:
                            --wildcard;
                            break;
                        case VersionPart.PRERELEASE:
                            --wildcard;
                            --wildcard;
                            break;
                    }
                    ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                    ranges[$-1] ~= SimpleRange("<", semVer.inc(wildcard).appendPrerelease0);
                    break;
                case "~>":
                    final switch (wildcard)
                    {
                        case VersionPart.MAJOR:
                            return;
                        case VersionPart.MINOR:
                            --wildcard;
                            break;
                        case VersionPart.PATCH:
                        case VersionPart.PRERELEASE:
                            --wildcard;
                            --wildcard;
                            break;
                    }
                    ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                    ranges[$-1] ~= SimpleRange("<", semVer.inc(wildcard).appendPrerelease0);
                    break;
                case "^":
                    if (wildcard == VersionPart.MAJOR || !semVer.prerelease.empty)
                        return;
                    if (semVer.ids[VersionPart.MAJOR] != 0)
                    {
                        ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                        ranges[$-1] ~= SimpleRange("<", semVer.inc(VersionPart.MAJOR).appendPrerelease0);
                    }
                    else if (semVer.ids[VersionPart.MINOR] != 0)
                    {
                        ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                        ranges[$-1] ~= SimpleRange("<", semVer.inc(VersionPart.MINOR).appendPrerelease0);
                    } 
                    else
                    {
                        ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                        ranges[$-1] ~= SimpleRange("<", semVer.inc(VersionPart.PATCH).appendPrerelease0);
                    }
                    break;
                default:
                    enforce(false, "Unexpected operator %s".format(operator));
                    break;
            }
            semVerRange = m.captures.post;
        }
        isValid = true;
    }

    private static VersionPart wildcardAt(string[3] semVer)
    {
        foreach (i; VersionPart.MAJOR..VersionPart.PRERELEASE)
        {
            if (["", "*", "X", "x"].canFind(semVer[i]))
                return i;
        }
        return VersionPart.PRERELEASE;
    }

    unittest
    {
        assert(wildcardAt(["*", "", ""]) == VersionPart.MAJOR);
        assert(wildcardAt(["X", "", ""]) == VersionPart.MAJOR);
        assert(wildcardAt(["1", "", ""]) == VersionPart.MINOR);
        assert(wildcardAt(["1", "x", ""]) == VersionPart.MINOR);
        assert(wildcardAt(["1", "2", ""]) == VersionPart.PATCH);
        assert(wildcardAt(["1", "2", "x"]) == VersionPart.PATCH);
        assert(wildcardAt(["1", "2", "3"]) == VersionPart.PRERELEASE);
    }

    private static string expand(string[4] semVer)
    {
        VersionPart wildcard = wildcardAt(semVer[0..3]);
        if (wildcard != VersionPart.PRERELEASE)
        {
            if (semVer[wildcard+1..$].any!`!["", "*", "X", "x"].canFind(a)`)
                return "";
            foreach (j; wildcard..VersionPart.PRERELEASE)
                semVer[j] = "0";
        }
        string result = "%-(%s.%)".format(semVer[0..3]);
        if (!semVer[3].empty)
            result ~= semVer[3];
        return result;
    }

    unittest
    {
        assert(expand(["*", "", "", ""]) == "0.0.0");
        assert(expand(["X", "", "", ""]) == "0.0.0");
        assert(expand(["1", "2", "3", ""]) == "1.2.3");
        assert(expand(["1", "2", "3", "-abc"]) == "1.2.3-abc");
        assert(expand(["1", "2", "", ""]) == "1.2.0");
        assert(expand(["1", "2", "", "-abc"]) == "");
        assert(expand(["1", "2", "x", ""]) == "1.2.0");
        assert(expand(["1", "", "", ""]) == "1.0.0");
        assert(expand(["1", "x", "", ""]) == "1.0.0");
    }

    /**
     * Return expanded string representation.
     */
    string toString() const
    {
        if (!isValid)
            return "<invalid_semver_range>";

        return "%(%(%s %) || %)".format(ranges);
    }

    /**
     * Property that indicates if this is a valid, semantic version range.
     */
    @property bool valid() const
    {
        return isValid;
    }

    private static bool simpleRangeSatisfiedBy(SimpleRange simpleRange, SemVer semVer)
    in
    {
        assert(semVer.valid);
        assert(["<", "<=", "=", ">=", ">"].canFind(simpleRange.op));
        assert(simpleRange.semVer.valid);
    }
    body
    {
        switch (simpleRange.op)
        {
            case "<":
                return semVer < simpleRange.semVer;
            case "<=":
                return semVer <= simpleRange.semVer;
            case "=":
                return semVer == simpleRange.semVer;
            case ">=":
                return semVer >= simpleRange.semVer;
            case ">":
                return semVer > simpleRange.semVer;
            default:
                return false;
        }
    }

    /**
     * Check if the $(LREF SemVer) $(D semVer) satisfies this $(LREF SemVerRange).
     */
    bool satisfiedBy(SemVer semVer)
    in
    {
        assert(semVer.valid);
        assert(valid);
    }
    body
    {
        return ranges.any!(r => r.all!(s => simpleRangeSatisfiedBy(s, semVer)));
    }

}

/**
 * Check if the $(LREF SemVer) $(D semVer) satisfies $(LREF SemVerRange) $(D semVerRange).
 */
bool satisfies(SemVer semVer, SemVerRange semVerRange)
{
    return semVerRange.satisfiedBy(semVer);
}

/**
 * Return the latest $(LREF Semver) from $(D semVers) array that satisfies
 * $(D semVerRange) $(LREF SemVerRange).
 */
SemVer maxSatisfying(SemVer[] semVers, SemVerRange semVerRange)
in
{
    assert(semVers.all!"a.valid");
    assert(semVerRange.valid);
}
body
{
    auto found = semVers.sort!"a > b".find!(a => satisfies(a, semVerRange));
    return found.empty ? SemVer("invalid") : found[0];
}

unittest
{
    assert(SemVerRange("1.x || >=2.5.0 || 5.0.0 - 7.2.3").valid);
    assert(!SemVerRange("blerg").valid);
    assert(!SemVerRange("git+https://user:password0123@github.com/foo").valid);

    assert(SemVer("1.2.3").satisfies(SemVerRange("1.x || >=2.5.0 || 5.0.0 - 7.2.3")));

    assert(SemVer("1.2.3").satisfies(SemVerRange("1.0.0 - 2.0.0")));
    assert(SemVer("1.0.0").satisfies(SemVerRange("1.0.0")));
    assert(SemVer("0.2.4").satisfies(SemVerRange(">=*")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("*")));
    assert(SemVer("v1.2.3-foo").satisfies(SemVerRange("*")));
    assert(SemVer("1.0.0").satisfies(SemVerRange(">=1.0.0")));
    assert(SemVer("1.0.1").satisfies(SemVerRange(">=1.0.0")));
    assert(SemVer("1.1.0").satisfies(SemVerRange(">=1.0.0")));
    assert(SemVer("1.0.1").satisfies(SemVerRange(">1.0.0")));
    assert(SemVer("1.1.0").satisfies(SemVerRange(">1.0.0")));
    assert(SemVer("2.0.0").satisfies(SemVerRange("<=2.0.0")));
    assert(SemVer("1.9999.9999").satisfies(SemVerRange("<=2.0.0")));
    assert(SemVer("0.2.9").satisfies(SemVerRange("<=2.0.0")));
    assert(SemVer("1.9999.9999").satisfies(SemVerRange("<2.0.0")));
    assert(SemVer("0.2.9").satisfies(SemVerRange("<2.0.0")));
    assert(SemVer("1.0.0").satisfies(SemVerRange(">=1.0.0")));
    assert(SemVer("1.0.1").satisfies(SemVerRange(">=1.0.0")));
    assert(SemVer("1.1.0").satisfies(SemVerRange(">=1.0.0")));
    assert(SemVer("1.0.1").satisfies(SemVerRange(">1.0.0")));
    assert(SemVer("1.1.0").satisfies(SemVerRange(">1.0.0")));
    assert(SemVer("2.0.0").satisfies(SemVerRange("<=2.0.0")));
    assert(SemVer("1.9999.9999").satisfies(SemVerRange("<=2.0.0")));
    assert(SemVer("0.2.9").satisfies(SemVerRange("<=2.0.0")));
    assert(SemVer("1.9999.9999").satisfies(SemVerRange("<2.0.0")));
    assert(SemVer("0.2.9").satisfies(SemVerRange("<2.0.0")));
    assert(SemVer("v0.1.97").satisfies(SemVerRange(">=0.1.97")));
    assert(SemVer("0.1.97").satisfies(SemVerRange(">=0.1.97")));
    assert(SemVer("1.2.4").satisfies(SemVerRange("0.1.20 || 1.2.4")));
    assert(SemVer("0.0.0").satisfies(SemVerRange(">=0.2.3 || <0.0.1")));
    assert(SemVer("0.2.3").satisfies(SemVerRange(">=0.2.3 || <0.0.1")));
    assert(SemVer("0.2.4").satisfies(SemVerRange(">=0.2.3 || <0.0.1")));
    assert(SemVer("2.1.3").satisfies(SemVerRange("2.x.x")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("1.2.x")));
    assert(SemVer("2.1.3").satisfies(SemVerRange("1.2.x || 2.x")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("1.2.x || 2.x")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("x")));
    assert(SemVer("2.1.3").satisfies(SemVerRange("2.*.*")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("1.2.*")));
    assert(SemVer("2.1.3").satisfies(SemVerRange("1.2.* || 2.*")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("1.2.* || 2.*")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("*")));
    assert(SemVer("2.1.2").satisfies(SemVerRange("2")));
    assert(SemVer("2.3.1").satisfies(SemVerRange("2.3")));
    assert(SemVer("2.4.0").satisfies(SemVerRange("~2.4")));
    assert(SemVer("2.4.5").satisfies(SemVerRange("~2.4")));
    assert(SemVer("3.2.2").satisfies(SemVerRange("~>3.2.1")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("~1")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("~>1")));
    assert(SemVer("1.0.2").satisfies(SemVerRange("~1.0")));
    assert(SemVer("1.0.12").satisfies(SemVerRange("~1.0.3")));
    assert(SemVer("1.0.0").satisfies(SemVerRange(">=1")));
    assert(SemVer("1.1.1").satisfies(SemVerRange("<1.2")));
    assert(SemVer("1.1.9").satisfies(SemVerRange("<=1.2")));
    assert(SemVer("1.0.0-bet").satisfies(SemVerRange("1")));
    assert(SemVer("0.5.5").satisfies(SemVerRange("~v0.5.4-pre")));
    assert(SemVer("0.5.4").satisfies(SemVerRange("~v0.5.4-pre")));
    assert(SemVer("0.7.2").satisfies(SemVerRange("=0.7.x")));
    assert(SemVer("0.7.2").satisfies(SemVerRange(">=0.7.x")));
    assert(SemVer("0.7.0-asdf").satisfies(SemVerRange("=0.7.x")));
    assert(SemVer("0.7.0-asdf").satisfies(SemVerRange(">=0.7.x")));
    assert(SemVer("0.6.2").satisfies(SemVerRange("<=0.7.x")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("~1.2.1 >=1.2.3")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("~1.2.1 =1.2.3")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("~1.2.1 1.2.3")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("~1.2.1 >=1.2.3 1.2.3")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("~1.2.1 1.2.3 >=1.2.3")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("~1.2.1 1.2.3")));
    assert(SemVer("1.2.3").satisfies(SemVerRange(">=1.2.1 1.2.3")));
    assert(SemVer("1.2.3").satisfies(SemVerRange("1.2.3 >=1.2.1")));
    assert(SemVer("1.2.3").satisfies(SemVerRange(">=1.2.3 >=1.2.1")));
    assert(SemVer("1.2.3").satisfies(SemVerRange(">=1.2.1 >=1.2.3")));
    assert(SemVer("1.2.3-beta").satisfies(SemVerRange("<=1.2.3")));
    assert(SemVer("1.3.0-beta").satisfies(SemVerRange(">1.2")));
    assert(SemVer("1.2.8").satisfies(SemVerRange(">=1.2")));
    assert(SemVer("1.8.1").satisfies(SemVerRange("^1.2.3")));
    assert(SemVer("1.2.3-beta").satisfies(SemVerRange("^1.2.3")));
    assert(SemVer("0.1.2").satisfies(SemVerRange("^0.1.2")));
    assert(SemVer("0.1.2").satisfies(SemVerRange("^0.1")));
    assert(SemVer("1.4.2").satisfies(SemVerRange("^1.2")));
    assert(SemVer("1.4.2").satisfies(SemVerRange("^1.2 ^1")));
    assert(SemVer("1.2.0-pre").satisfies(SemVerRange("^1.2")));
    assert(SemVer("1.2.3-pre").satisfies(SemVerRange("^1.2.3")));

    assert(!SemVer("2.2.3").satisfies(SemVerRange("1.0.0 - 2.0.0")));
    assert(!SemVer("1.0.1").satisfies(SemVerRange("1.0.0")));
    assert(!SemVer("0.0.0").satisfies(SemVerRange(">=1.0.0")));
    assert(!SemVer("0.0.1").satisfies(SemVerRange(">=1.0.0")));
    assert(!SemVer("0.1.0").satisfies(SemVerRange(">=1.0.0")));
    assert(!SemVer("0.0.1").satisfies(SemVerRange(">1.0.0")));
    assert(!SemVer("0.1.0").satisfies(SemVerRange(">1.0.0")));
    assert(!SemVer("3.0.0").satisfies(SemVerRange("<=2.0.0")));
    assert(!SemVer("2.9999.9999").satisfies(SemVerRange("<=2.0.0")));
    assert(!SemVer("2.2.9").satisfies(SemVerRange("<=2.0.0")));
    assert(!SemVer("2.9999.9999").satisfies(SemVerRange("<2.0.0")));
    assert(!SemVer("2.2.9").satisfies(SemVerRange("<2.0.0")));
    assert(!SemVer("v0.1.93").satisfies(SemVerRange(">=0.1.97")));
    assert(!SemVer("0.1.93").satisfies(SemVerRange(">=0.1.97")));
    assert(!SemVer("1.2.3").satisfies(SemVerRange("0.1.20 || 1.2.4")));
    assert(!SemVer("0.0.3").satisfies(SemVerRange(">=0.2.3 || <0.0.1")));
    assert(!SemVer("0.2.2").satisfies(SemVerRange(">=0.2.3 || <0.0.1")));
    assert(!SemVer("1.1.3").satisfies(SemVerRange("2.x.x")));
    assert(!SemVer("3.1.3").satisfies(SemVerRange("2.x.x")));
    assert(!SemVer("1.3.3").satisfies(SemVerRange("1.2.x")));
    assert(!SemVer("3.1.3").satisfies(SemVerRange("1.2.x || 2.x")));
    assert(!SemVer("1.1.3").satisfies(SemVerRange("1.2.x || 2.x")));
    assert(!SemVer("1.1.3").satisfies(SemVerRange("2.*.*")));
    assert(!SemVer("3.1.3").satisfies(SemVerRange("2.*.*")));
    assert(!SemVer("1.3.3").satisfies(SemVerRange("1.2.*")));
    assert(!SemVer("3.1.3").satisfies(SemVerRange("1.2.* || 2.*")));
    assert(!SemVer("1.1.3").satisfies(SemVerRange("1.2.* || 2.*")));
    assert(!SemVer("1.1.2").satisfies(SemVerRange("2")));
    assert(!SemVer("2.4.1").satisfies(SemVerRange("2.3")));
    assert(!SemVer("2.5.0").satisfies(SemVerRange("~2.4")));
    assert(!SemVer("2.3.9").satisfies(SemVerRange("~2.4")));
    assert(!SemVer("3.3.2").satisfies(SemVerRange("~>3.2.1")));
    assert(!SemVer("3.2.0").satisfies(SemVerRange("~>3.2.1")));
    assert(!SemVer("0.2.3").satisfies(SemVerRange("~1")));
    assert(!SemVer("2.2.3").satisfies(SemVerRange("~>1")));
    assert(!SemVer("1.1.0").satisfies(SemVerRange("~1.0")));
    assert(!SemVer("1.0.0").satisfies(SemVerRange("<1")));
    assert(!SemVer("1.1.1").satisfies(SemVerRange(">=1.2")));
    assert(!SemVer("1.3.0").satisfies(SemVerRange("<=1.2")));
    assert(!SemVer("2.0.0-beta").satisfies(SemVerRange("1")));
    assert(!SemVer("0.5.4-alpha").satisfies(SemVerRange("~v0.5.4-beta")));
    assert(!SemVer("1.0.0-beta").satisfies(SemVerRange("<1")));
    assert(!SemVer("0.8.2").satisfies(SemVerRange("=0.7.x")));
    assert(!SemVer("0.6.2").satisfies(SemVerRange(">=0.7.x")));
    assert(!SemVer("0.7.2").satisfies(SemVerRange("<=0.7.x")));
    assert(!SemVer("1.2.3-beta").satisfies(SemVerRange("<1.2.3")));
    assert(!SemVer("1.2.3-beta").satisfies(SemVerRange("=1.2.3")));
    assert(!SemVer("1.2.8").satisfies(SemVerRange(">1.3")));
    assert(!SemVer("2.0.0-alpha").satisfies(SemVerRange("^1.2.3")));
    assert(!SemVer("1.2.2").satisfies(SemVerRange("^1.2.3")));
    assert(!SemVer("1.1.9").satisfies(SemVerRange("^1.2")));
    assert(!SemVer("2.0.0-pre").satisfies(SemVerRange("^1.2.3")));

    auto semVers = [SemVer("0.8.0"), SemVer("1.0.0"), SemVer("1.1.0")];
    assert(semVers.maxSatisfying(SemVerRange("<=1.0.0")) == SemVer("1.0.0"));
    assert(semVers.maxSatisfying(SemVerRange(">=1.0")) == SemVer("1.1.0"));
}
