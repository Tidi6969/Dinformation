using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace DCAD.Dinformation.Data
{
    internal sealed class DcadDataPathResolver
    {
        private static readonly HashSet<string> KnownFolders =
            new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            { "DData", "DUser", "DProgram", "DHelp", "Dicon" };

        private readonly Func<string> _readCadSupportPaths;
        private readonly Action<string> _diagnostic;
        private IList<string> _cachedSupportPaths;

        internal DcadDataPathResolver(Func<string> readCadSupportPaths, Action<string> diagnostic)
        {
            _readCadSupportPaths = readCadSupportPaths ?? throw new ArgumentNullException(nameof(readCadSupportPaths));
            _diagnostic = diagnostic;
        }

        internal IList<string> GetRegisteredSupportPaths()
        {
            if (_cachedSupportPaths != null)
                return new List<string>(_cachedSupportPaths);

            string raw = _readCadSupportPaths();
            if (string.IsNullOrWhiteSpace(raw))
                throw new InvalidOperationException("PATH_SOURCE_UNAVAILABLE: CAD Support File Search Path is empty or unavailable.");

            var result = new List<string>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string item in raw.Split(new[] { ';', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries))
            {
                string path = NormalizeAbsoluteDirectory(item);
                if (string.IsNullOrEmpty(path))
                {
                    Diag("REJECT_INVALID_SUPPORT_PATH Raw=" + Quote(item));
                    continue;
                }
                if (!Directory.Exists(path))
                {
                    Diag("REJECT_MISSING_SUPPORT_PATH Path=" + Quote(path));
                    continue;
                }
                if (seen.Add(path)) result.Add(path);
                else Diag("SKIP_DUPLICATE_SUPPORT_PATH Path=" + Quote(path));
            }

            if (result.Count == 0)
                throw new InvalidOperationException("PATH_SOURCE_UNAVAILABLE: CAD returned no existing absolute Support File Search Path entries.");

            _cachedSupportPaths = result;
            return new List<string>(_cachedSupportPaths);
        }

        internal IList<string> GetNamedFolders(string folderName)
        {
            if (!KnownFolders.Contains(folderName ?? string.Empty))
                throw new ArgumentException("UNKNOWN_LOGICAL_FOLDER", nameof(folderName));

            var result = new List<string>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string root in GetRegisteredSupportPaths())
            {
                string leaf = SafeFileName(root);
                string candidate;
                if (KnownFolders.Contains(leaf))
                {
                    // DCAD-DATA-001: a registered DData/DProgram/etc. entry never grants
                    // permission to infer a sibling DUser folder.
                    if (!leaf.Equals(folderName, StringComparison.OrdinalIgnoreCase))
                        continue;
                    candidate = root;
                }
                else
                {
                    candidate = Path.Combine(root, folderName);
                }

                if (Directory.Exists(candidate) && seen.Add(candidate))
                    result.Add(candidate);
            }
            return result;
        }

        internal IList<string> FindAllFiles(string folderName, string fileName)
        {
            RequireFileNameOnly(fileName);
            var matches = new List<string>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (string folder in GetNamedFolders(folderName))
            {
                string direct = Path.Combine(folder, fileName);
                if (File.Exists(direct))
                {
                    if (seen.Add(direct)) matches.Add(direct);
                    continue;
                }

                // Case-insensitive fallback is restricted to the same resolved folder.
                string other = Directory.GetFiles(folder).FirstOrDefault(path =>
                    string.Equals(Path.GetFileName(path), fileName, StringComparison.OrdinalIgnoreCase));
                if (!string.IsNullOrEmpty(other) && seen.Add(other)) matches.Add(other);
            }
            return matches;
        }

        private static void RequireFileNameOnly(string name)
        {
            if (string.IsNullOrWhiteSpace(name) || name == "." || name == ".." ||
                !string.Equals(Path.GetFileName(name), name, StringComparison.Ordinal) ||
                name.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0)
                throw new ArgumentException("FILE_NAME_ONLY_REQUIRED", nameof(name));
        }

        private static string NormalizeAbsoluteDirectory(string raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return null;
            string value = raw.Trim();
            if (value.Length >= 2 && value[0] == '"' && value[value.Length - 1] == '"')
                value = value.Substring(1, value.Length - 2);
            value = Environment.ExpandEnvironmentVariables(value);
            if (!Path.IsPathRooted(value)) return null;
            try
            {
                string full = Path.GetFullPath(value);
                string root = Path.GetPathRoot(full);
                return string.Equals(full, root, StringComparison.OrdinalIgnoreCase)
                    ? full
                    : full.TrimEnd('\\', '/');
            }
            catch (ArgumentException) { return null; }
            catch (NotSupportedException) { return null; }
            catch (PathTooLongException) { return null; }
        }

        private static string SafeFileName(string path)
        {
            try { return Path.GetFileName((path ?? string.Empty).TrimEnd('\\', '/')); }
            catch { return string.Empty; }
        }

        private void Diag(string message)
        {
            if (_diagnostic == null) return;
            try { _diagnostic(message ?? string.Empty); } catch { }
        }

        private static string Quote(string value)
        {
            return "\"" + (value ?? string.Empty).Replace("\"", "'") + "\"";
        }
    }
}
