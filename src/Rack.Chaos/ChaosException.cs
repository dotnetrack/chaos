using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Rack.Chaos
{
    /// <summary>
    /// An exception thrown by the chaos monkey whenever it introduces chaos into our product.
    /// </summary>
    public class ChaosException : Exception
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="ChaosException"/> class.
        /// </summary>
        public ChaosException()
            : base("The chaos monkey was naughty and injected this exception!")
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="ChaosException"/> class.
        /// </summary>
        /// <param name="message">The message that describes the error.</param>
        public ChaosException(string message)
            : base(message)
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="ChaosException"/> class.
        /// </summary>
        /// <param name="message">The message that describes the error.</param>
        /// <param name="inner">The inner exception.</param>
        public ChaosException(string message, Exception inner)
            : base(message, inner)
        {
        }
    }
}
