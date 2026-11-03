using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text.RegularExpressions;

namespace DCAD.Dinformation.Core
{
    internal static class LanguageResourceAudit
    {
        internal static bool TryRun(out string error)
        {
            error = string.Empty;
            try
            {
                Dictionary<int, Dictionary<string, string>> blocks = ReadBlocks();
                for (int language = 0; language < 6; language++)
                    if (!blocks.ContainsKey(language)) return Fail("Missing Lang_" + language + ".", out error);
                Dictionary<string, string> english = blocks[0];
                if (english.Count == 0) return Fail("Lang_0 is empty.", out error);
                for (int language = 1; language < 6; language++)
                {
                    if (blocks[language].Count != english.Count) return Fail("Lang_" + language + " key count differs from Lang_0.", out error);
                    foreach (string key in english.Keys)
                    {
                        string value;
                        if (!blocks[language].TryGetValue(key, out value)) return Fail("Lang_" + language + " missing key " + key + ".", out error);
                        if (string.IsNullOrWhiteSpace(value)) return Fail("Lang_" + language + " has empty value at key " + key + ".", out error);
                        if (PlaceholderSignature(value) != PlaceholderSignature(english[key])) return Fail("Lang_" + language + " placeholder mismatch at key " + key + ".", out error);
                    }
                }
                return true;
            }
            catch (System.Exception ex) { error = ex.ToString(); return false; }
        }

        private static Dictionary<int, Dictionary<string, string>> ReadBlocks()
        {
            var result = new Dictionary<int, Dictionary<string, string>>();
            Assembly assembly = typeof(LanguageResourceAudit).Assembly;
            string resourceName = null;
            foreach (string name in assembly.GetManifestResourceNames()) if (name.EndsWith(".lang.dat", StringComparison.OrdinalIgnoreCase)) { resourceName = name; break; }
            if (string.IsNullOrEmpty(resourceName)) throw new InvalidOperationException("Missing embedded lang.dat.");
            using (Stream stream = assembly.GetManifestResourceStream(resourceName))
            using (var reader = new StreamReader(stream))
            {
                int current = -1; string line;
                while ((line = reader.ReadLine()) != null)
                {
                    string trimmed = line.Trim();
                    Match header = Regex.Match(trimmed, @"^Lang_(\d+)\(([^_()]+)_([^_()]+)\)$");
                    if (header.Success) { current = int.Parse(header.Groups[1].Value); if (!result.ContainsKey(current)) result[current] = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase); continue; }
                    if (trimmed == "-") { current = -1; continue; }
                    if (current < 0 || trimmed.Length == 0 || trimmed.StartsWith("#") || trimmed.StartsWith(";") || trimmed.StartsWith("//")) continue;
                    int equal = line.IndexOf('='); if (equal <= 0) continue;
                    string key = line.Substring(0, equal).Trim(); string value = line.Substring(equal + 1);
                    if (key.Length == 0) continue;
                    if (result[current].ContainsKey(key)) throw new InvalidOperationException("Duplicate language key: " + key + " in Lang_" + current + ".");
                    result[current][key] = value;
                }
            }
            return result;
        }

        private static string PlaceholderSignature(string value)
        {
            MatchCollection matches = Regex.Matches(value ?? string.Empty, @"\{\d+[^}]*\}");
            var list = new List<string>(); foreach (Match match in matches) list.Add(match.Value); list.Sort(StringComparer.Ordinal); return string.Join("|", list.ToArray());
        }
        private static bool Fail(string message, out string error) { error = message; return false; }
    }
}
