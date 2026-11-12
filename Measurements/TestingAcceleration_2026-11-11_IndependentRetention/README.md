# Independent validation retention

The actual validation, formatting and complete tooling commands passed at
`86376bd7b0e9d89e348a03e27ce943e2a0d78a5a`, with engine
`0573d4f3b294e3c3655349eb618ec7105b3d89b2`. The next identical invocation reused
all three completed checks without rewriting their original evidence.

This one fresh/reuse pair took 105,615.01 ms and 2,247.8336 ms respectively.
It demonstrates the independent-check path only. Another project's Source build
was active; this is not a controlled performance study, whole-project speedup,
native/ETW/installation result or hosted acceptance. Original values and scope are
in [the observations](independent-checks.json) and [provenance](provenance.json).

The complete tooling suite also passed its formatter, agent-guidance, output,
build-identity, SDK-routing and 15 public-wrapper fixture cases. Recording native
boundaries verify that later native failure preserves independent bytes and that
all native profiles/live ETW/ARM64/package/installation calls remain requested.
Forced failed, interrupted, corrupt and input-mutating independent outcomes cannot
reuse an older green. Actual native qualification remains separate.

Earlier failed attempts are retained under the owning checkout's `.build`: the
first discovery-environment test accidentally restored an absent variable as an
empty variable; its exact state is now restored. The first actual command campaign
exposed a fixture module import escaping into the real caller. Fixture modules now
stay in fixture child processes. Formatter output containment remains enforced.
These failures were fixed before this successful actual-command observation.
