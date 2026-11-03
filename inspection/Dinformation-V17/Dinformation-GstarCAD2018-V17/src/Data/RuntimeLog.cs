using System;
using System.IO;
using System.Text;

namespace DCAD.Dinformation.Data
{
    internal static class RuntimeLog
    {
        private static readonly object SyncRoot = new object();
        private static readonly string LogDirectory =
            Path.Combine(Path.GetTempPath(), "DCAD", "Dinformation", "log");

        public static void Info(string message) { Write("INFO", message, null); }
        public static void Warn(string message) { Write("WARN", message, null); }
        public static void Error(string message, System.Exception exception) { Write("ERROR", message, exception); }

        private static void Write(string level, string message, System.Exception exception)
        {
            var line = new StringBuilder();
            line.Append(DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff"));
            line.Append(" [").Append(level).Append("] ");
            line.Append(message ?? string.Empty);
            if (exception != null)
            {
                line.Append(" | ").Append(exception.GetType().FullName).Append(": ").Append(exception.Message);
                if (!string.IsNullOrWhiteSpace(exception.StackTrace))
                {
                    line.AppendLine();
                    line.Append(exception.StackTrace);
                }
            }

            lock (SyncRoot)
            {
                try
                {
                    Directory.CreateDirectory(LogDirectory);
                    string path = Path.Combine(LogDirectory, "Dinformation-" + DateTime.Now.ToString("yyyyMMdd") + ".log");
                    File.AppendAllText(path, line + Environment.NewLine, new UTF8Encoding(false));
                }
                catch
                {
                    // Runtime diagnostics must never create/write DProgram, DData or arbitrary CAD folders.
                }
            }
        }
    }
}
