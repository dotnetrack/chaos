using NLog;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace Rack.Chaos
{
    /// <summary>
    /// Introduces chaos (failures, delays) during code execution.
    /// </summary>
    public static class ChaosMonkey
    {
        private static Logger Logger = LogManager.GetCurrentClassLogger();

        [ThreadStatic]
        private static Random random;
        private static readonly Random GlobalRandom = new Random();

        private static readonly Task NullTask = Task.FromResult<object>(null);

        /// <summary>
        /// Globally enables or disables the injection of chaos.
        /// </summary>
        public static bool IsEnabled { get; set; }

        /// <summary>
        /// Potentially introduce chaos in the system, for a given chaos scenario.
        /// </summary>
        /// <param name="scenario">The scenario.</param>
        public static Task ChaosAsync(ChaosScenario scenario)
        {
            // TODO: Assert.ParamIsNotNull(scenario, nameof(scenario));

            if (IsEnabled)
            {
                return DoChaosAsync(scenario);
            }
            else
            {
                return NullTask;
            }
        }

        /// <summary>
        /// Potentially introduce chaos in the system, for a given chaos scenario.
        /// </summary>
        /// <param name="scenario">The scenario.</param>
        public static void Chaos(ChaosScenario scenario)
        {
            // TODO: Assert.ParamIsNotNull(scenario, nameof(scenario));

            if (IsEnabled)
            {
                if (scenario.Delay > 0)
                {
                    DelayAsync(scenario).Wait();
                }

                Fail(scenario);
            }
        }

        private static async Task DoChaosAsync(ChaosScenario scenario)
        {
            if (IsEnabled)
            {
                if (scenario.Delay > 0)
                {
                    await DelayAsync(scenario);
                }

                Fail(scenario);
            }
        }

        private static void Fail(ChaosScenario scenario)
        {
            if (ShouldFail(scenario.FailureRate))
            {
                throw new ChaosException($"The chaos monkey was naughty and injected this exception! ({scenario.Name})");
            }
        }

        private static bool ShouldFail(double failureRate)
        {
            return failureRate > 0 && GetThreadSafeRandom().NextDouble() <= failureRate;
        }

        private static Task DelayAsync(ChaosScenario scenario)
        {
            Logger.Info($"Delaying {scenario.Delay}ms for chaos scenario '{scenario.Name}'");
            return Task.Delay(scenario.Delay);
        }

        // Random is not thread-safe so use an instance per thread
        // See https://blogs.msdn.microsoft.com/pfxteam/2009/02/19/getting-random-numbers-in-a-thread-safe-way/
        private static Random GetThreadSafeRandom()
        {
            if (random == null)
            {
                int seed;
                lock (GlobalRandom)
                {
                    seed = GlobalRandom.Next();
                    random = new Random(seed);
                }
            }

            return random;
        }
    }
}
