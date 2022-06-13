/**
 * License: <a href="http://opensource.org/licenses/MIT">MIT</a>.
 * Authors: Dragos Carp
 *
 * See_Also: <a href="http://semver.org">Semantic Versioning 2.0</a>,
 * <a href="https://github.com/isaacs/node-semver">The semantic versioner for npm</a>
 */

module semver;

import std.algorithm;
import std.range;

/**
 * The version part of a version number.
 */
enum VersionPart
{
    /** major number */
    MAJOR,
    /** minor number */
    MINOR,
    /** patch number */
    PATCH,
    /** prerelease suffix */
    PRERELEASE,
    /** build suffix */
    BUILD,
}

/**
 * Represent a semantic version number MAJOR[.MINOR[.PATCH]][-PRERELEASE][+BUILD].
 */
struct SemVer
{
    private uint[3] ids;
    private string[] prerelease;
    private string[] build;

    private bool _isValid;

    /**
     * Creates and validates a version number from a string.
     *
     * If string format is invalid it just sets the $(D_PARAM isValid) property to $(D_KEYWORD false).
     */
    this(string semVer)
    {
        import std.array : array;
        import std.conv : to;
        import std.regex : matchAll, regex;

        _isValid = false;
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

        _isValid = true;
    }

    /**
     * Return the canonical string format.
     */
    string toString() const
    {
        import std.string : format;

        if (!_isValid)
            return "<invalid_semver>";

        string semVer = "%(%s.%)".format(ids);
        if (!prerelease.empty)
            semVer ~= "-" ~ "%-(%s.%)".format(prerelease);
        if (!build.empty)
            semVer ~= "+" ~ "%-(%s.%)".format(build);
        return semVer;
    }

    /**
     * Property that indicates whether this $(D_PSYMBOL SemVer) is valid.
     */
    bool isValid() const
    {
        return _isValid;
    }

    /**
     * Property that indicates whether this $(D_PSYMBOL SemVer) is stable.
     */
    bool isStable() const
    {
        return prerelease.empty;
    }

    /**
     * Increment version number.
     */
    SemVer increment(VersionPart versionPart) const
    in
    {
        assert(this.isValid);
    }
    out(result)
    {
        assert(result.isValid);
    }
    do
    {
        SemVer result = "0";
        foreach (i; VersionPart.MAJOR .. versionPart)
            result.ids[i] = this.ids[i];
        if (versionPart != VersionPart.PRERELEASE)
            result.ids[versionPart] = this.ids[versionPart]+1;
        return result;
    }

    private SemVer appendPrerelease0()
    {
        if (prerelease.empty)
            prerelease ~= "0";
        return this;
    }

    unittest
    {
        assert(SemVer("1.2.3").increment(VersionPart.MAJOR) == SemVer("2.0.0"));
        assert(SemVer("1.2.3").increment(VersionPart.MINOR) == SemVer("1.3.0"));
        assert(SemVer("1.2.3-alpha").increment(VersionPart.MINOR) == SemVer("1.3.0"));
        assert(SemVer("1.2.3").increment(VersionPart.PATCH) == SemVer("1.2.4"));
        assert(SemVer("1.2.3-alpha").increment(VersionPart.PATCH) == SemVer("1.2.4"));
        assert(SemVer("1.2.3").increment(VersionPart.PRERELEASE) == SemVer("1.2.3"));
        assert(SemVer("1.2.3-alpha").increment(VersionPart.PRERELEASE) == SemVer("1.2.3"));
    }

    /**
     * Compare this $(D_PSYMBOL SemVer) with the $(D_PARAM other) $(D_PSYMBOL SemVer).
     *
     * Note that the build parts are considered for this operation.
     * Please use $(D_PSYMBOL differAt) to find whether the versions differ only on the build part.
     */
    int opCmp(ref const SemVer other) const
    in
    {
        assert(this.isValid);
        assert(other.isValid);
    }
    do
    {
        foreach (i; 0..ids.length)
        {
            if (ids[i] != other.ids[i])
                return ids[i] < other.ids[i] ? -1 : 1;
        }

        int compareSufix(const string[] suffix, const string[] anotherSuffix)
        {
            import std.conv : to;
            import std.string : isNumeric;

            if (!suffix.empty && anotherSuffix.empty)
                return -1;
            if (suffix.empty && !anotherSuffix.empty)
                return 1;

            foreach (a, b; lockstep(suffix, anotherSuffix))
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
            if (suffix.length != anotherSuffix.length)
                return suffix.length < anotherSuffix.length ? -1 : 1;
            else
                return 0;
        }

        auto result = compareSufix(prerelease, other.prerelease);
        if (result != 0)
            return result;
        else
            return compareSufix(build, other.build);
    }

    /// ditto
    int opCmp(const SemVer other) const
    {
        return this.opCmp(other);
    }

    /**
     * Check for equality between this $(D_PSYMBOL SemVer) and the $(D_PARAM other) $(D_PSYMBOL SemVer).
     *
     * Note that the build parts are considered for this operation.
     * Please use $(D_PSYMBOL differAt) to find whether the versions differ only on the build part.
     */
    bool opEquals(ref const SemVer other) const
    {
        return this.opCmp(other) == 0;
    }

    /// ditto
    bool opEquals(const SemVer other) const
    {
        return this.opEquals(other);
    }

    /**
     * Compare two $(B different) versions and return the parte they differ on.
     */
    VersionPart differAt(ref const SemVer other) const
    in
    {
        assert(this != other);
    }
    do
    {
        foreach (i; VersionPart.MAJOR .. VersionPart.PRERELEASE)
        {
            if (ids[i] != other.ids[i])
                return i;
        }

        if (prerelease != other.prerelease)
            return VersionPart.PRERELEASE;

        if (build != other.build)
            return VersionPart.BUILD;

        assert(0, "Call 'differAt' for unequal versions only");
    }

    /// ditto
    VersionPart differAt(const SemVer other) const
    {
        return this.differAt(other);
    }
}

unittest
{
    assert(!SemVer().isValid);
    assert(!SemVer("1.2-.alpha.32").isValid);
    assert(!SemVer("1.2-alpha+").isValid);
    assert(!SemVer("1.2-alpha_").isValid);
    assert(!SemVer("1.2+32.").isValid);
    assert(!SemVer("1.2.5.6").isValid);
    assert(!SemVer("").isValid);
    assert(SemVer("1").isStable);
    assert(SemVer("1.0").isStable);
    assert(SemVer("1.0.0").isStable);
    assert(SemVer("1.0+build3.").isStable);
    assert(SemVer("1.0.0+build.5").isStable);
    assert(!SemVer("1.0.0-alpha").isStable);
    assert(!SemVer("1.0.0-alpha.1").isStable);

    assert(SemVer("1.0.0-alpha") < SemVer("1.0.0-alpha.1"));
    assert(SemVer("1.0.0-alpha.1") < SemVer("1.0.0-alpha.beta"));
    assert(SemVer("1.0.0-alpha.beta") < SemVer("1.0.0-beta"));
    assert(SemVer("1.0.0-beta") < SemVer("1.0.0-beta.2"));
    assert(SemVer("1.0.0-beta.2") < SemVer("1.0.0-beta.11"));
    assert(SemVer("1.0.0-beta.11") < SemVer("1.0.0-rc.1"));
    assert(SemVer("1.0.0-rc.1") < SemVer("1.0.0"));
    assert(SemVer("1.0.0-rc.1") > SemVer("1.0.0-rc.1+build.5"));
    assert(SemVer("1.0.0-rc.1+build.5") == SemVer("1.0.0-rc.1+build.5"));

    assert(SemVer("1.0.0").differAt(SemVer("2")) == VersionPart.MAJOR);
    assert(SemVer("1.0.0").differAt(SemVer("1.1.1")) == VersionPart.MINOR);
    assert(SemVer("1.0.0-rc.1").differAt(SemVer("1.0.1-rc.1")) == VersionPart.PATCH);
    assert(SemVer("1.0.0-alpha").differAt(SemVer("1.0.0-beta")) == VersionPart.PRERELEASE);
    assert(SemVer("1.0.0-rc.1").differAt(SemVer("1.0.0")) == VersionPart.PRERELEASE);
    assert(SemVer("1.0.0-rc.1").differAt(SemVer("1.0.0-rc.1+build.5")) == VersionPart.BUILD);
}

/**
 * Represent a semantic version range [~|~>|^|<|<=|=|>=|>]MAJOR[.MINOR[.PATCH]].
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

    private bool _isValid;

    /**
     * Creates and validates a semantic version range from a string.
     *
     * If string format is invalid it just sets the $(D_PARAM isValid) property to $(D_KEYWORD false).
     */
    this(string semVerRange)
    {
        import std.exception : enforce;
        import std.regex : matchFirst, regex;
        import std.string : format, strip, stripLeft;

        _isValid = false;
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
            if (!semVer.isValid)
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
                            ranges[$-1] ~= SimpleRange("<", semVer.increment(--wildcard).appendPrerelease0);
                            break;
                        case VersionPart.PRERELEASE:
                            ranges[$-1] ~= SimpleRange("=", semVer);
                            break;
                        case VersionPart.BUILD:
                            assert(0, "Unexpected build part wildcard");
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
                        case VersionPart.BUILD:
                            assert(0, "Unexpected build part wildcard");
                    }
                    ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                    ranges[$-1] ~= SimpleRange("<", semVer.increment(wildcard).appendPrerelease0);
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
                        case VersionPart.BUILD:
                            assert(0, "Unexpected build part wildcard");
                    }
                    ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                    ranges[$-1] ~= SimpleRange("<", semVer.increment(wildcard).appendPrerelease0);
                    break;
                case "^":
                    if (wildcard == VersionPart.MAJOR || !semVer.prerelease.empty)
                        return;
                    if (semVer.ids[VersionPart.MAJOR] != 0)
                    {
                        ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                        ranges[$-1] ~= SimpleRange("<", semVer.increment(VersionPart.MAJOR).appendPrerelease0);
                    }
                    else if (semVer.ids[VersionPart.MINOR] != 0)
                    {
                        ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                        ranges[$-1] ~= SimpleRange("<", semVer.increment(VersionPart.MINOR).appendPrerelease0);
                    }
                    else
                    {
                        ranges[$-1] ~= SimpleRange(">=", semVer.appendPrerelease0);
                        ranges[$-1] ~= SimpleRange("<", semVer.increment(VersionPart.PATCH).appendPrerelease0);
                    }
                    break;
                default:
                    enforce(false, "Unexpected operator %s".format(operator));
                    break;
            }
            semVerRange = m.captures.post;
        }
        _isValid = true;
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
        import std.string : format;

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
        import std.string : format;

        if (!_isValid)
            return "<invalid_semver_range>";

        return "%(%(%s %) || %)".format(ranges);
    }

    /**
     * Property that indicates whether this $(D_PSYMBOL SemVerRange) is valid.
     */
    bool isValid() const
    {
        return _isValid;
    }

    private static bool simpleRangeSatisfiedBy(SimpleRange simpleRange, SemVer semVer)
    in
    {
        assert(semVer.isValid);
        assert(["<", "<=", "=", ">=", ">"].canFind(simpleRange.op));
        assert(simpleRange.semVer.isValid);
    }
    do
    {
        semVer.build = null;

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
     * Check if the $(D_PSYMBOL SemVer) $(D_PARAM semVer) satisfies this $(D_PSYMBOL SemVerRange).
     */
    bool satisfiedBy(SemVer semVer)
    in
    {
        assert(semVer.isValid);
        assert(isValid);
    }
    do
    {
        return ranges.any!(r => r.all!(s => simpleRangeSatisfiedBy(s, semVer)));
    }

}

/**
 * Check if the $(D_PSYMBOL SemVer) $(D_PARAM semVer) satisfies $(LREF SemVerRange) $(D_PARAM semVerRange).
 */
bool satisfies(SemVer semVer, SemVerRange semVerRange)
{
    return semVerRange.satisfiedBy(semVer);
}

/**
 * Return the latest $(D_PSYMBOL Semver) from $(D_PARAM semVers) array that satisfies
 * $(D_PARAM semVerRange) $(D_PSYMBOL SemVerRange).
 */
SemVer maxSatisfying(SemVer[] semVers, SemVerRange semVerRange)
in
{
    assert(semVers.all!"a.isValid");
    assert(semVerRange.isValid);
}
do
{
    auto found = semVers.sort!"a > b".find!(a => satisfies(a, semVerRange));
    return found.empty ? SemVer("invalid") : found[0];
}

unittest
{
    assert(!SemVerRange().isValid);
    assert(SemVerRange("1.x || >=2.5.0 || 5.0.0 - 7.2.3").isValid);
    assert(!SemVerRange("blerg").isValid);
    assert(!SemVerRange("git+https://user:password0123@github.com/foo").isValid);

    assert(SemVer("1.2.3").satisfies(SemVerRange("1.x || >=2.5.0 || 5.0.0 - 7.2.3")));

    assert(SemVer("1.2.3").satisfies(SemVerRange("1.0.0 - 2.0.0")));
    assert(SemVer("1.0.0").satisfies(SemVerRange("1.0.0")));
    assert(SemVer("1.0.0+build.5").satisfies(SemVerRange("1.0.0")));
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

    auto semVers = [SemVer("1.1.0"), SemVer("1.0.0"), SemVer("0.8.0")];
    assert(semVers.maxSatisfying(SemVerRange("<=1.0.0")) == SemVer("1.0.0"));
    assert(semVers.maxSatisfying(SemVerRange(">=1.0")) == SemVer("1.1.0"));

    semVers = [SemVer("1.0.0+build.3"), SemVer("1.0.0+build.1"), SemVer("1.1.0")];
    assert(semVers.maxSatisfying(SemVerRange("<=1.0.0")) == SemVer("1.0.0+build.3"));
    assert(semVers.maxSatisfying(SemVerRange(">=1.0")) == SemVer("1.1.0"));
}
