namespace Music {

    public delegate V TaskFunc<V> ();

    private class Worker<V> : Object {

        private TaskFunc<V> _task;
        private SourceFunc _callback;
        private V? _result = null;

        public Worker (TaskFunc<V> task, SourceFunc callback) {
            _task = task;
            _callback = callback;
        }

        public V? result {
            get {
                return _result;
            }
        }

        private void run () {
            _result = _task ();
            Idle.add ((owned) _callback);
        }

        private static Once<ThreadPool<Worker<V>>> async_pool;
        internal static unowned ThreadPool<Worker> get_async_pool () {
            return async_pool.once(() => {
                int num_threads = (int)get_num_processors ();
                try {
                    return new ThreadPool<Worker<V>>.with_owned_data((tdata) => {
                        tdata.run();
                    }, num_threads, false);
                } catch (Error err) {
                    Process.abort ();
                }
            });
        }
    }

    public static async V run_task_async<V> (TaskFunc<V> task) {
        var worker  = new Worker<V> (task, run_task_async<V>.callback);
        try {
            Worker.get_async_pool ().add (worker);
            yield;
        } catch (Error e) {
        }
        return worker.result;
    }
}