using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace System.Threading
{
    public enum ThreadPriority
    {
        BelowNormal
    }

    public enum ThreadState
    {
        Running,
        Unstarted,
        Stopped,
    }
    public class Thread
    {
        Action action;
        Task currentTask;

        public Thread(Action action)
        {
            this.action = action;
        }

        public ThreadPriority Priority { get; set; }
        public ThreadState ThreadState
        {
            get {
                if (currentTask != null)
                {
                    switch (currentTask.Status)
                    {
                        case TaskStatus.Canceled:
                            break;
                        case TaskStatus.Faulted:
                        case TaskStatus.RanToCompletion:
                            return ThreadState.Stopped;
                        case TaskStatus.WaitingForChildrenToComplete:
                        case TaskStatus.Running:
                            return ThreadState.Running;
                        default:
                            break;
                    }
                }
                return ThreadState.Unstarted;
            }
        }

        public void Start()
        {
            currentTask = new Task(action).ContinueWith ((t) => { currentTask = null; });
            currentTask.Start();
        }

        public static void Sleep(int milliseconds)
        {
            Task.Delay(milliseconds).Wait();
        }
    }

    public class WaitCallback
    {
        public WaitCallback(Action<object> action)
        {
            this.Action = action;
        }

        internal Action<object> Action { get; private set; }
    }

    public class ThreadPool
    {
        public static void QueueUserWorkItem(WaitCallback a, object userObject)
        {
            Task.Run(() => {
                a.Action(userObject);
            });
        }
    }

}
namespace System
{
    public interface ICloneable
    {
        object Clone();
    }
}
