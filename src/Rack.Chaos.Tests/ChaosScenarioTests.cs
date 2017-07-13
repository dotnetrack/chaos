using NUnit.Framework;
using Rack.Chaos;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Rack.Chaos.Tests
{
    [TestFixture]
    public class ChaosScenarioTests
    {
        [Test]
        public void LoadScenariosFromStaticFieldsShouldFindScenarios()
        {
            var actualScenarios = ChaosScenario.LoadScenariosFromStaticFields(typeof(TestChaosScenarios));

            var expectedScenarios = new ChaosScenario[] { TestChaosScenarios.Scenario1, TestChaosScenarios.Scenario2, TestChaosScenarios.Scenario3 };
            CollectionAssert.AreEqual(expectedScenarios, actualScenarios, "Unexpected mismatch of loaded ChaosScenarios");
        }

        private static class TestChaosScenarios
        {
            public static readonly ChaosScenario Scenario1 = new ChaosScenario("Scenario 1");
            public static readonly ChaosScenario Scenario2 = new ChaosScenario("Scenario 2");
            public static readonly ChaosScenario Scenario3 = new ChaosScenario("Scenario 3");
        }
    }
}
