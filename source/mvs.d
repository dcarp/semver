module mvs;

import std.algorithm : all, canFind, find, sort;
import std.exception : enforce;
import std.range : empty;
import std.typecons : Tuple;

import semver;

alias ModuleVersion = Tuple!(string, "moduleName", SemVer, "version_");

private SemVer minSatisfying(SemVer[] semVers, SemVerRange[] constraints)
{
    auto found = semVers.sort!"a < b"
        .find!(candidate => constraints
                .all!(range => candidate.satisfies(range)));
    return found.empty ? SemVer("invalid") : found[0];
}

private void enqueue(ref string[] modules, string moduleName)
{
    if (!modules.canFind(moduleName))
        modules ~= moduleName;
}

private bool removeConstraint(ref SemVerRange[] constraints, SemVerRange range)
{
    foreach (i, existing; constraints)
    {
        if (existing == range)
        {
            constraints[i] = constraints[$ - 1];
            constraints = constraints[0 .. $ - 1];
            return true;
        }
    }
    return false;
}

/**
 * Resolves a dependency graph using Minimal Version Selection.
 *
 * Params:
 *   rootConstraints = root module constraints by module name.
 *   availableVersions = all available versions per module.
 *   dependencies = dependency constraints by source module version.
 *
 * Returns:
 *   The resolved selected version for each module.
 *
 * Throws:
 *   `Exception` if the graph is invalid or unsatisfiable.
 */
SemVer[string] minimalVersionSelection(
    scope SemVerRange[string] rootConstraints,
    scope SemVer[][string] availableVersions,
    scope SemVerRange[string][ModuleVersion] dependencies)
{
    SemVer[string] selected;

    SemVerRange[][string] constraints;
    SemVerRange[string][string] emittedDependencies;
    string[] worklist;

    foreach (source, outgoing; dependencies)
    {
        enforce(!source.moduleName.empty && source.version_.isValid,
            "Invalid dependency source: " ~ source.moduleName);
        foreach (moduleName, range; outgoing)
        {
            enforce(!moduleName.empty && range.isValid,
                "Invalid dependency constraint for module: " ~
                    (moduleName.empty ? source.moduleName : moduleName));
        }
    }

    foreach (moduleName, range; rootConstraints)
    {
        enforce(!moduleName.empty && range.isValid,
            "Invalid root constraint for module: " ~ moduleName);
        constraints[moduleName] ~= range;
        worklist.enqueue(moduleName);
    }

    while (!worklist.empty)
    {
        auto moduleName = worklist[0];
        worklist = worklist[1 .. $];

        auto moduleConstraints = moduleName in constraints;
        if (moduleConstraints is null || moduleConstraints.empty)
        {
            if (moduleName in selected)
            {
                selected.remove(moduleName);
                if (auto previousDependencies = moduleName in emittedDependencies)
                {
                    foreach (dependencyModule, dependencyRange; *previousDependencies)
                    {
                        if (auto dependencyConstraints = dependencyModule in constraints)
                        {
                            if (removeConstraint(*dependencyConstraints, dependencyRange))
                                worklist.enqueue(dependencyModule);
                        }
                    }
                    emittedDependencies.remove(moduleName);
                }
            }
            continue;
        }

        auto versionsPtr = moduleName in availableVersions;
        enforce(!(versionsPtr is null || versionsPtr.empty),
            "Unable to resolve module: " ~ moduleName);

        auto resolved = minSatisfying((*versionsPtr).dup, *moduleConstraints);
        enforce(resolved.isValid, "Unable to resolve module: " ~ moduleName);

        bool changed = true;
        if (auto current = moduleName in selected)
            changed = (*current != resolved);
        if (!changed)
            continue;

        selected[moduleName] = resolved;

        if (auto previousDependencies = moduleName in emittedDependencies)
        {
            foreach (dependencyModule, dependencyRange; *previousDependencies)
            {
                if (auto dependencyConstraints = dependencyModule in constraints)
                {
                    if (removeConstraint(*dependencyConstraints, dependencyRange))
                        worklist.enqueue(dependencyModule);
                }
            }
        }

        SemVerRange[string] activeDependencies;
        if (auto outgoing = ModuleVersion(moduleName, resolved) in dependencies)
            activeDependencies = (*outgoing).dup;

        foreach (dependencyModule, dependencyRange; activeDependencies)
        {
            constraints[dependencyModule] ~= dependencyRange;
            worklist.enqueue(dependencyModule);
        }

        if (activeDependencies.length == 0)
            emittedDependencies.remove(moduleName);
        else
            emittedDependencies[moduleName] = activeDependencies;
    }

    return selected;
}

unittest
{
    SemVerRange[string] roots = [
        "A": SemVerRange(">=1.0.0"),
    ];

    SemVer[][string] available = [
        "A": [SemVer("1.0.0"), SemVer("1.1.0"), SemVer("2.0.0")],
        "B": [SemVer("1.0.0"), SemVer("1.1.0"), SemVer("2.0.0")],
        "C": [SemVer("1.0.0"), SemVer("1.2.0")],
    ];

    SemVerRange[string][ModuleVersion] dependencies;
    dependencies[ModuleVersion("A", SemVer("1.0.0"))] = [
        "B": SemVerRange(">=1.0.0"),
    ];
    dependencies[ModuleVersion("A", SemVer("1.1.0"))] = [
        "B": SemVerRange(">=1.1.0"),
    ];
    dependencies[ModuleVersion("A", SemVer("2.0.0"))] = [
        "B": SemVerRange(">=2.0.0"),
    ];
    dependencies[ModuleVersion("B", SemVer("1.0.0"))] = [
        "C": SemVerRange(">=1.0.0"),
    ];
    dependencies[ModuleVersion("B", SemVer("1.1.0"))] = [
        "C": SemVerRange(">=1.2.0"),
    ];
    dependencies[ModuleVersion("B", SemVer("2.0.0"))] = [
        "C": SemVerRange(">=1.2.0"),
    ];

    auto selected = minimalVersionSelection(roots, available, dependencies);
    assert(selected["A"] == SemVer("1.0.0"));
    assert(selected["B"] == SemVer("1.0.0"));
    assert(selected["C"] == SemVer("1.0.0"));

    roots["C"] = SemVerRange(">=1.2.0");
    selected = minimalVersionSelection(roots, available, dependencies);
    assert(selected["A"] == SemVer("1.0.0"));
    assert(selected["B"] == SemVer("1.0.0"));
    assert(selected["C"] == SemVer("1.2.0"));
}

unittest
{
    SemVerRange[string] roots = [
        "A": SemVerRange(">=1.0.0"),
    ];

    SemVer[][string] available;
    available["A"] = [SemVer("1.0.0")];
    available["B"] = [SemVer("1.0.0"), SemVer("1.2.0")];

    SemVerRange[string][ModuleVersion] dependencies;
    dependencies[ModuleVersion("A", SemVer("1.0.0"))] = [
        "B": SemVerRange(">=1.2.0"),
    ];

    auto selected = minimalVersionSelection(roots, available, dependencies);
    assert(selected["A"] == SemVer("1.0.0"));
    assert(selected["B"] == SemVer("1.2.0"));
}

unittest
{
    import std.exception : assertThrown;

    SemVerRange[string] roots = [
        "A": SemVerRange(">=1.0.0"),
        "B": SemVerRange(">=1.0.0"),
    ];

    SemVer[][string] available = [
        "A": [SemVer("1.0.0"), SemVer("1.1.0")],
        "B": [SemVer("1.0.0")],
    ];

    SemVerRange[string][ModuleVersion] dependencies;
    dependencies[ModuleVersion("B", SemVer("1.0.0"))] = [
        "A": SemVerRange(">=2.0.0"),
    ];

    assertThrown(minimalVersionSelection(roots, available, dependencies));
}
