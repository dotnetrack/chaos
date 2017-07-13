using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Rack.Chaos.Tests
{
    [TestFixture]
    public class ChaosMonkeyTests
    {
        private bool chaosMonkeyWasEnabled;

        [SetUp]
        public void SetUp()
        {
            // TODO: Currently failing on loading NLog, maybe not ready for .NET Standard?
            chaosMonkeyWasEnabled = ChaosMonkey.IsEnabled;
            ChaosMonkey.IsEnabled = true;
        }

        [TearDown]
        public void TearDown()
        {
            ChaosMonkey.IsEnabled = chaosMonkeyWasEnabled;
        }

        [Test]
        public async Task ShouldThrowOnExpectedChaos()
        {
            ChaosScenario noChaos = new ChaosScenario("No Chaos", failureRate: 0.0);
            ChaosScenario fullChaos = new ChaosScenario("Full Chaos", failureRate: 1.0);

            // No exception is expected
            ChaosMonkey.Chaos(noChaos);
            await ChaosMonkey.ChaosAsync(noChaos);

            Assert.Throws<ChaosException>(() => ChaosMonkey.Chaos(fullChaos));
            Assert.ThrowsAsync<ChaosException>(async () => await ChaosMonkey.ChaosAsync(fullChaos));
        }

        [Test]
        public async Task ShouldDelayOnChaos()
        {
            ChaosScenario noChaos = new ChaosScenario("No Chaos", failureRate: 0.0);
            ChaosScenario delayChaos = new ChaosScenario("Full Chaos", delay: 10);

            var sw = Stopwatch.StartNew();

            // Expect no delays from Chaos that is not configured
            sw.Restart();
            ChaosMonkey.Chaos(noChaos);
            Assert.Less(sw.ElapsedMilliseconds, 10, "No chaos resulted in an unexpected delay.");

            sw.Restart();
            await ChaosMonkey.ChaosAsync(noChaos);
            Assert.Less(sw.ElapsedMilliseconds, 10, "No chaos resulted in an unexpected delay.");

            // Expect delays from Chaos that is configured
            sw.Restart();
            ChaosMonkey.Chaos(delayChaos);
            Assert.GreaterOrEqual(sw.ElapsedMilliseconds, 10, "No chaos resulted in an unexpected delay.");

            sw.Restart();
            await ChaosMonkey.ChaosAsync(delayChaos);
            Assert.GreaterOrEqual(sw.ElapsedMilliseconds, 10, "No chaos resulted in an unexpected delay.");
        }

        [Test]
        public async Task ShouldNotThrowOrDelayWhenNotEnabled()
        {
            // Disable the monkey, it will be restored to its original state no matter what in TearDown.
            ChaosMonkey.IsEnabled = false;

            ChaosScenario fullChaos = new ChaosScenario("Full Chaos", failureRate: 1.0, delay: 1000);

            var sw = Stopwatch.StartNew();

            // Expect no delays or exceptions when disabled
            sw.Restart();
            ChaosMonkey.Chaos(fullChaos);
            Assert.Less(sw.ElapsedMilliseconds, 10, "No chaos resulted in an unexpected delay.");

            sw.Restart();
            await ChaosMonkey.ChaosAsync(fullChaos);
            Assert.Less(sw.ElapsedMilliseconds, 10, "No chaos resulted in an unexpected delay.");
        }
    }
}
