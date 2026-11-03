using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using DCAD.Dinformation.Data;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DCAD.Dinformation.Core
{
    internal static class Lang
    {
        private const string MisSetFileName = "MIS_SET.SET";
        private const int MisSetLanguageLineNumber = 28;
        private const int FallbackLangId = 0;
        private static readonly Dictionary<int, Dictionary<string, string>> Texts = new Dictionary<int, Dictionary<string, string>>();
        private static readonly Regex HeaderRegex = new Regex(@"^Lang_(\d+)\(([^_()]+)_([^_()]+)\)$", RegexOptions.Compiled);
        private static int _currentLangId = FallbackLangId;
        private static bool _warnedThisCommand;

        public static void BeginCommand()
        {
            _warnedThisCommand = false;
        }

        public static int CurrentLanguageId { get { return _currentLangId; } }

        public static void Reload()
        {
            Texts.Clear();
            _currentLangId = FallbackLangId;

            string text = ReadEmbeddedLangDat();
            if (string.IsNullOrEmpty(text))
            {
                Warn("Cannot read embedded lang.dat from Dinformation assembly.");
                return;
            }

            Parse(text);
            if (!Texts.ContainsKey(FallbackLangId))
            {
                Warn("Embedded lang.dat does not contain Lang_0(English_en-US).");
                return;
            }

            int requested = ReadLanguageId();
            if (Texts.ContainsKey(requested))
            {
                _currentLangId = requested;
                return;
            }

            _currentLangId = FallbackLangId;
            Warn(F("LangWarnRequestedBlockMissing", requested) + " " + T("LangWarnFallbackSuffix"));
        }

        public static string T(string key)
        {
            if (string.IsNullOrEmpty(key)) return string.Empty;
            Dictionary<string, string> block;
            string value;
            if (Texts.TryGetValue(_currentLangId, out block) && block.TryGetValue(key, out value)) return Decode(value);
            if (Texts.TryGetValue(FallbackLangId, out block) && block.TryGetValue(key, out value)) return Decode(value);
            return key;
        }

        public static string F(string key, params object[] args)
        {
            string format = T(key);
            if (args == null || args.Length == 0) return format;
            try { return string.Format(CultureInfo.CurrentCulture, format, args); }
            catch (FormatException) { return format; }
        }

        private static int ReadLanguageId()
        {
            string path = FindMisSetPath();
            if (string.IsNullOrEmpty(path))
            {
                Warn(T("LangWarnMisSetMissing") + " " + T("LangWarnFallbackSuffix"));
                return FallbackLangId;
            }

            try
            {
                string line = ReadSpecificLineCompatible(path, MisSetLanguageLineNumber);
                if (line == null)
                {
                    RuntimeLog.Warn("[DCAD-DATA][WARN][INVALID_SCHEMA] CAD=" + CadSupportPathProvider.HostName +
                        " | Module=Dinformation | Folder=DUser | File=MIS_SET.SET | Reason=Missing line 28 | Path=" + path);
                    Warn(T("LangWarnMisSetLineMissing") + " " + T("LangWarnFallbackSuffix"));
                    return FallbackLangId;
                }

                int id;
                if (!TryParseLeadingInt(line, out id) || id < 0)
                {
                    RuntimeLog.Warn("[DCAD-DATA][WARN][INVALID_VALUE] CAD=" + CadSupportPathProvider.HostName +
                        " | Module=Dinformation | Folder=DUser | File=MIS_SET.SET | Line=28 | Value=" + SafeLog(line) +
                        " | Path=" + path);
                    Warn(T("LangWarnMisSetInvalid") + " " + T("LangWarnFallbackSuffix"));
                    return FallbackLangId;
                }
                return id;
            }
            catch (UnauthorizedAccessException ex)
            {
                RuntimeLog.Error("[DCAD-DATA][ERROR][ACCESS_DENIED] CAD=" + CadSupportPathProvider.HostName +
                    " | Module=Dinformation | Folder=DUser | File=MIS_SET.SET | Path=" + path, ex);
                Warn(F("LangWarnMisSetReadError", ex.Message) + " " + T("LangWarnFallbackSuffix"));
                return FallbackLangId;
            }
            catch (IOException ex)
            {
                RuntimeLog.Error("[DCAD-DATA][ERROR][IO_ERROR] CAD=" + CadSupportPathProvider.HostName +
                    " | Module=Dinformation | Folder=DUser | File=MIS_SET.SET | Path=" + path, ex);
                Warn(F("LangWarnMisSetReadError", ex.Message) + " " + T("LangWarnFallbackSuffix"));
                return FallbackLangId;
            }
            catch (System.Exception ex)
            {
                RuntimeLog.Error("[DCAD-DATA][ERROR][READ_ERROR] CAD=" + CadSupportPathProvider.HostName +
                    " | Module=Dinformation | Folder=DUser | File=MIS_SET.SET | Path=" + path, ex);
                Warn(F("LangWarnMisSetReadError", ex.Message) + " " + T("LangWarnFallbackSuffix"));
                return FallbackLangId;
            }
        }

        private static string FindMisSetPath()
        {
            try
            {
                var resolver = new DcadDataPathResolver(
                    CadSupportPathProvider.ReadSupportPathText,
                    message => RuntimeLog.Info("[DCAD-DATA][INFO][PATH_DIAGNOSTIC] CAD=" + CadSupportPathProvider.HostName + " | " + message));

                IList<string> supports = resolver.GetRegisteredSupportPaths();
                IList<string> duserFolders = resolver.GetNamedFolders("DUser");
                IList<string> matches = resolver.FindAllFiles("DUser", MisSetFileName);
                string selected = matches.Count == 0 ? null : matches[0];
                string profile = CadSupportPathProvider.TryReadProfileName();

                RuntimeLog.Info(
                    "[DCAD-DATA][INFO][PATH_RESOLVE] CAD=" + CadSupportPathProvider.HostName +
                    " | Profile=" + (string.IsNullOrWhiteSpace(profile) ? "<unavailable>" : profile) +
                    " | Module=Dinformation | Folder=DUser | File=MIS_SET.SET" +
                    " | SupportPath=" + JoinForLog(supports) +
                    " | Candidates=" + JoinForLog(duserFolders) +
                    " | Resolved=" + (selected ?? "<none>") +
                    " | Status=" + (selected == null ? "MISSING" : "OK"));

                if (matches.Count > 1)
                {
                    RuntimeLog.Warn(
                        "[DCAD-DATA][WARN][CONFLICT] CAD=" + CadSupportPathProvider.HostName +
                        " | Module=Dinformation | Folder=DUser | File=MIS_SET.SET" +
                        " | Selected=" + selected +
                        " | Matches=" + JoinForLog(matches) +
                        " | Rule=first match by CAD Support File Search Path order");
                }

                return selected;
            }
            catch (InvalidOperationException ex)
            {
                RuntimeLog.Error(
                    "[DCAD-DATA][ERROR][PATH_SOURCE_UNAVAILABLE] CAD=" + CadSupportPathProvider.HostName +
                    " | Module=Dinformation | Folder=DUser | File=MIS_SET.SET", ex);
                return null;
            }
            catch (UnauthorizedAccessException ex)
            {
                RuntimeLog.Error(
                    "[DCAD-DATA][ERROR][ACCESS_DENIED] CAD=" + CadSupportPathProvider.HostName +
                    " | Module=Dinformation | Folder=DUser | File=MIS_SET.SET", ex);
                return null;
            }
            catch (IOException ex)
            {
                RuntimeLog.Error(
                    "[DCAD-DATA][ERROR][IO_ERROR] CAD=" + CadSupportPathProvider.HostName +
                    " | Module=Dinformation | Folder=DUser | File=MIS_SET.SET", ex);
                return null;
            }
        }

        // MIS_SET.SET is historical shared data. Dinformation reads only line 28 and never rewrites it.
        // UTF-8/ANSI without BOM are ASCII-compatible for the numeric selector, so no transcoding is needed.
        private static string ReadSpecificLineCompatible(string path, int lineNumber)
        {
            byte[] data = File.ReadAllBytes(path);
            if (data.Length >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF)
                return GetDecodedLine(new UTF8Encoding(false, true).GetString(data, 3, data.Length - 3), lineNumber);
            if (data.Length >= 2 && data[0] == 0xFF && data[1] == 0xFE)
                return GetDecodedLine(Encoding.Unicode.GetString(data, 2, data.Length - 2), lineNumber);
            if (data.Length >= 2 && data[0] == 0xFE && data[1] == 0xFF)
                return GetDecodedLine(Encoding.BigEndianUnicode.GetString(data, 2, data.Length - 2), lineNumber);

            int currentLine = 1;
            int start = 0;
            for (int i = 0; i <= data.Length; i++)
            {
                bool atEnd = i == data.Length;
                bool newline = !atEnd && (data[i] == 0x0A || data[i] == 0x0D);
                if (!atEnd && !newline) continue;

                if (currentLine == lineNumber)
                {
                    var sb = new StringBuilder();
                    for (int j = start; j < i; j++)
                        sb.Append(data[j] < 0x80 ? (char)data[j] : '?');
                    return sb.ToString();
                }

                currentLine++;
                if (!atEnd && data[i] == 0x0D && i + 1 < data.Length && data[i + 1] == 0x0A) i++;
                start = i + 1;
            }
            return null;
        }

        private static string GetDecodedLine(string text, int lineNumber)
        {
            if (text == null) return null;
            string[] lines = text.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
            return lines.Length < lineNumber ? null : lines[lineNumber - 1];
        }

        private static string ReadEmbeddedLangDat()
        {
            try
            {
                Assembly assembly = typeof(Lang).Assembly;
                string resourceName = assembly.GetManifestResourceNames().FirstOrDefault(name =>
                    name.EndsWith(".lang.dat", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(name, "lang.dat", StringComparison.OrdinalIgnoreCase));
                if (string.IsNullOrEmpty(resourceName)) return null;
                using (Stream stream = assembly.GetManifestResourceStream(resourceName))
                using (var reader = stream == null ? null : new StreamReader(stream))
                    return reader == null ? null : reader.ReadToEnd();
            }
            catch { return null; }
        }

        private static void Parse(string text)
        {
            int? currentId = null;
            Dictionary<string, string> current = null;
            foreach (string raw in text.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n'))
            {
                string line = (raw ?? string.Empty).Trim();
                if (line.Length == 0 || line.StartsWith("#") || line.StartsWith(";") || line.StartsWith("//")) continue;
                Match match = HeaderRegex.Match(line);
                if (match.Success)
                {
                    Flush(currentId, current);
                    currentId = int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture);
                    current = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                    continue;
                }
                if (line == "-")
                {
                    Flush(currentId, current);
                    currentId = null;
                    current = null;
                    continue;
                }
                if (current == null) continue;
                int equal = line.IndexOf('=');
                if (equal <= 0) continue;
                string key = line.Substring(0, equal).Trim();
                if (key.Length == 0) continue;
                current[key] = line.Substring(equal + 1);
            }
            Flush(currentId, current);
        }

        private static void Flush(int? id, Dictionary<string, string> block)
        {
            if (id.HasValue && block != null && block.Count > 0) Texts[id.Value] = block;
        }

        private static string Decode(string value)
        {
            return (value ?? string.Empty)
                .Replace("\\r\\n", Environment.NewLine)
                .Replace("\\n", Environment.NewLine)
                .Replace("\\t", "\t");
        }

        private static bool TryParseLeadingInt(string raw, out int value)
        {
            value = 0;
            if (string.IsNullOrWhiteSpace(raw)) return false;
            Match match = Regex.Match(raw, @"[-+]?\d+");
            return match.Success && int.TryParse(match.Value, NumberStyles.Integer, CultureInfo.InvariantCulture, out value);
        }

        private static string JoinForLog(IEnumerable<string> values)
        {
            if (values == null) return "<none>";
            string[] items = values.Where(v => !string.IsNullOrWhiteSpace(v)).ToArray();
            return items.Length == 0 ? "<none>" : string.Join("; ", items);
        }

        private static string SafeLog(string value)
        {
            string text = (value ?? string.Empty).Replace("\r", " ").Replace("\n", " ");
            return text.Length <= 160 ? text : text.Substring(0, 160) + "...";
        }

        private static void Warn(string message)
        {
            if (_warnedThisCommand) return;
            _warnedThisCommand = true;
            try
            {
                var doc = AcApp.DocumentManager.MdiActiveDocument;
                if (doc != null && doc.Editor != null)
                    doc.Editor.WriteMessage("\n[Dinformation Language] " + (message ?? string.Empty));
            }
            catch { }
        }
    }
}
