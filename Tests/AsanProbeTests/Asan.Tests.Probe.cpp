#include <memory>

#include "TestSupport/TestSupport.Tests.FailureReports.h"

// Deliberate fault, executed only by the ASan validation entry. Never ship or run as a normal test.
int main(int argc, char** argv)
{
    RedSalamander::TestSupport::RouteFailureReportsAwayFromDialogs();
    if (argc == 2 && std::strcmp(argv[1], "--failure-report-self-test") == 0)
        return RedSalamander::TestSupport::RunFailureReportRoutingSelfTest();
    auto allocation      = std::make_unique<int[]>(1);
    volatile int* memory = allocation.get();
    memory[argc]         = 7;
    return memory[0];
}
