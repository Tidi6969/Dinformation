using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using Gssoft.Gscad.ApplicationServices;
using Gssoft.Gscad.DatabaseServices;
using Gssoft.Gscad.Geometry;
using Gssoft.Gscad.Runtime;
using GstarApp = Gssoft.Gscad.ApplicationServices.Application;
using DCAD.Dinformation.Data;

namespace DCAD.Dinformation.Core
{
    internal static class LispInfoEngine
    {
        private const string TemplateSuffix = "Dinformation-Tooltip.lsp.tpl";
        private const string BootstrapMarker = "@@BOOTSTRAP@@";
        private const string GetInfoFunction = "dcad-dinformation-getinfo";
        private const string ResetFunction = "dcad-dinformation-reset";
        private const string TempPrefix = "DINFINFO_";
        private static bool _loaded;
        private static Func<ResultBuffer, ResultBuffer> _invokeLisp;

        private static readonly string[] LispLanguageKeys = new string[]
        {
            "AlignAligned",
            "AlignBottomCenter",
            "AlignBottomLeft",
            "AlignBottomRight",
            "AlignCenter",
            "AlignFit",
            "AlignLeft",
            "AlignMiddle",
            "AlignMiddleCenter",
            "AlignMiddleLeft",
            "AlignMiddleRight",
            "AlignRight",
            "AlignTopCenter",
            "AlignTopLeft",
            "AlignTopRight",
            "Alignment",
            "Angle",
            "ArcAngle",
            "ArcLength",
            "Area",
            "Associative",
            "BlockName",
            "Center",
            "Circumference",
            "Closed",
            "ConstantWidth",
            "Content",
            "CurveType",
            "Default",
            "Degree",
            "DegreeUnit",
            "Diameter",
            "DimStyle",
            "EndAngle",
            "EndPoint",
            "HatchIgnore",
            "HatchNormal",
            "HatchOuter",
            "HatchStyle",
            "Height",
            "ImageSize",
            "LabelHandle",
            "LabelLayer",
            "Length",
            "MajorRadius",
            "MinorRadius",
            "No",
            "None",
            "Off",
            "On",
            "Pattern",
            "Prompt",
            "Radius",
            "ReferencePath",
            "Rotation",
            "Scale",
            "ScaleX",
            "ScaleY",
            "ScaleZ",
            "StartAngle",
            "StartPoint",
            "StartPrompt",
            "Style",
            "Tag",
            "TextHeight",
            "TextOverride",
            "TextStyle",
            "TypeArc",
            "TypeAttribute",
            "TypeAttributeDefinition",
            "TypeBody",
            "TypeCircle",
            "TypeDimension",
            "TypeEllipse",
            "TypeFace3d",
            "TypeHatch",
            "TypeImage",
            "TypeInsert",
            "TypeLeader",
            "TypeLine",
            "TypeLwPolyline",
            "TypeMText",
            "TypeOleBorder",
            "TypePoint",
            "TypePolyline",
            "TypeProxy",
            "TypeRay",
            "TypeRegion",
            "TypeShape",
            "TypeSolid",
            "TypeSolid3d",
            "TypeSpline",
            "TypeText",
            "TypeTolerance",
            "TypeTrace",
            "TypeUnknown",
            "TypeXline",
            "Value",
            "VariableWidth",
            "VersionNumber",
            "WordPolyline",
            "WordSpline",
            "Yes",
        };

        public static void CleanupStaleFiles()
        {
            string root = ResolveWritableAsciiTempRoot(false);
            if (string.IsNullOrEmpty(root) || !Directory.Exists(root)) return;

            int currentPid = Process.GetCurrentProcess().Id;
            string[] files;
            try { files = Directory.GetFiles(root, TempPrefix + "*.lsp", SearchOption.TopDirectoryOnly); }
            catch { return; }

            foreach (string file in files)
            {
                int pid;
                if (!TryGetPid(file, out pid))
                {
                    TryDelete(file);
                    continue;
                }
                if (pid == currentPid)
                {
                    TryDelete(file);
                    continue;
                }

                bool running = false;
                try
                {
                    using (Process process = Process.GetProcessById(pid))
                        running = !process.HasExited;
                }
                catch { running = false; }
                if (!running) TryDelete(file);
            }
        }

        public static void LoadForCommand()
        {
            _loaded = false;
            CleanupStaleFiles();

            string template = ReadTemplate();
            if (string.IsNullOrEmpty(template) ||
                template.IndexOf(BootstrapMarker, StringComparison.Ordinal) < 0 ||
                template.IndexOf(BootstrapMarker, StringComparison.Ordinal) != template.LastIndexOf(BootstrapMarker, StringComparison.Ordinal))
                throw new InvalidOperationException(Lang.T("LispEngineTemplateMissing"));

            string root = ResolveWritableAsciiTempRoot(true);
            string tempFile = Path.Combine(root, TempPrefix + Process.GetCurrentProcess().Id + "_" + Guid.NewGuid().ToString("N") + ".lsp");
            string content = template.Replace(BootstrapMarker, BuildBootstrap());
            if (!LispTextEncoder.IsAscii(content))
                throw new InvalidOperationException(Lang.T("LispEngineAsciiError"));

            try
            {
                File.WriteAllText(tempFile, content, Encoding.ASCII);
                using (ResultBuffer args = new ResultBuffer(
                    new TypedValue((int)LispDataType.Text, "load"),
                    new TypedValue((int)LispDataType.Text, tempFile.Replace('\\', '/'))))
                using (ResultBuffer result = InvokeLisp(args))
                {
                    if (result == null)
                        throw new InvalidOperationException(Lang.T("LispEngineLoadError"));
                }
                _loaded = true;
                if (!ResetCore())
                {
                    _loaded = false;
                    throw new InvalidOperationException(Lang.T("LispEngineLoadError"));
                }
            }
            finally
            {
                TryDelete(tempFile);
            }
        }

        public static string GetTooltipText(Point3d worldPoint)
        {
            if (!_loaded) throw new InvalidOperationException("Dinformation LISP engine has not been loaded for this command.");

            using (ResultBuffer args = new ResultBuffer(
                new TypedValue((int)LispDataType.Text, GetInfoFunction),
                new TypedValue((int)LispDataType.Double, worldPoint.X),
                new TypedValue((int)LispDataType.Double, worldPoint.Y),
                new TypedValue((int)LispDataType.Double, worldPoint.Z)))
            using (ResultBuffer result = InvokeLisp(args))
            {
                return ResultToText(result);
            }
        }

        public static void Reset()
        {
            if (!_loaded) return;
            try
            {
                if (!ResetCore())
                    RuntimeLog.Warn("LISP engine reset returned no confirmation value.");
            }
            catch (System.Exception ex)
            {
                RuntimeLog.Error("LISP engine reset failed.", ex);
            }
        }

        private static bool ResetCore()
        {
            using (ResultBuffer args = new ResultBuffer(
                new TypedValue((int)LispDataType.Text, ResetFunction)))
            using (ResultBuffer result = InvokeLisp(args))
            {
                if (result == null) return false;
                TypedValue[] values = result.AsArray();
                return values.Any(value => value.TypeCode == (int)LispDataType.T_atom);
            }
        }

        private static ResultBuffer InvokeLisp(ResultBuffer args)
        {
            if (_invokeLisp == null)
            {
                MethodInfo method = typeof(GstarApp).GetMethod(
                    "Invoke",
                    BindingFlags.Public | BindingFlags.Static,
                    null,
                    new Type[] { typeof(ResultBuffer) },
                    null);
                if (method == null)
                    throw new MissingMethodException("GstarCAD 2027 managed API does not expose Application.Invoke(ResultBuffer).");

                try
                {
                    _invokeLisp = (Func<ResultBuffer, ResultBuffer>)Delegate.CreateDelegate(
                        typeof(Func<ResultBuffer, ResultBuffer>), method);
                }
                catch
                {
                    return (ResultBuffer)method.Invoke(null, new object[] { args });
                }
            }
            return _invokeLisp(args);
        }

        private static string ResultToText(ResultBuffer result)
        {
            if (result == null) return string.Empty;
            var lines = new List<string>();
            TypedValue[] values = result.AsArray();
            for (int i = 0; i < values.Length; i++)
            {
                if (values[i].TypeCode == (int)LispDataType.Text && values[i].Value != null)
                {
                    string line = DecodeCadUnicodeEscapes(Convert.ToString(values[i].Value));
                    if (!string.IsNullOrWhiteSpace(line)) lines.Add(line);
                }
            }
            return string.Join(Environment.NewLine, lines);
        }

        private static string DecodeCadUnicodeEscapes(string value)
        {
            if (string.IsNullOrEmpty(value)) return value ?? string.Empty;
            var builder = new StringBuilder(value.Length);
            for (int i = 0; i < value.Length; i++)
            {
                if (value[i] == '\\' && i + 6 < value.Length &&
                    (value[i + 1] == 'U' || value[i + 1] == 'u') && value[i + 2] == '+')
                {
                    int code = 0;
                    bool valid = true;
                    for (int j = 0; j < 4; j++)
                    {
                        int digit = HexValue(value[i + 3 + j]);
                        if (digit < 0) { valid = false; break; }
                        code = (code << 4) | digit;
                    }
                    if (valid)
                    {
                        builder.Append((char)code);
                        i += 6;
                        continue;
                    }
                }
                builder.Append(value[i]);
            }
            return builder.ToString();
        }

        private static int HexValue(char c)
        {
            if (c >= '0' && c <= '9') return c - '0';
            if (c >= 'A' && c <= 'F') return c - 'A' + 10;
            if (c >= 'a' && c <= 'f') return c - 'a' + 10;
            return -1;
        }

        private static string BuildBootstrap()
        {
            var sb = new StringBuilder();
            sb.AppendLine("(setq *dcad-dinf-lang* (list");
            foreach (string key in LispLanguageKeys)
            {
                sb.Append("  (cons ").Append(LispTextEncoder.ToLispStringLiteral(key)).Append(" ")
                  .Append(LispTextEncoder.ToLispStringLiteral(Lang.T(key))).AppendLine(")");
            }
            sb.AppendLine("))");
            return sb.ToString();
        }

        private static string ReadTemplate()
        {
            Assembly assembly = typeof(LispInfoEngine).Assembly;
            string resource = assembly.GetManifestResourceNames()
                .FirstOrDefault(name => name.EndsWith(TemplateSuffix, StringComparison.OrdinalIgnoreCase));
            if (string.IsNullOrEmpty(resource)) return null;
            using (Stream stream = assembly.GetManifestResourceStream(resource))
            {
                if (stream == null) return null;
                Encoding strictAscii = Encoding.GetEncoding(20127, EncoderFallback.ExceptionFallback, DecoderFallback.ExceptionFallback);
                using (var reader = new StreamReader(stream, strictAscii, false))
                    return reader.ReadToEnd();
            }
        }

        private static string ResolveWritableAsciiTempRoot(bool throwOnFailure)
        {
            var candidates = new List<string>();
            AddCandidate(candidates, Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "DCAD", "Temp", "Dinformation");
            AddCandidate(candidates, Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments), "DCAD", "Temp", "Dinformation");
            try { AddCandidate(candidates, Path.GetTempPath(), "DCAD", "Dinformation"); } catch { }

            foreach (string candidate in candidates)
            {
                string usable = PrepareCandidate(candidate);
                if (!string.IsNullOrEmpty(usable)) return usable;
            }
            if (throwOnFailure)
                throw new IOException(Lang.F("LispEngineTempError", "No writable ASCII temp directory."));
            return null;
        }

        private static void AddCandidate(List<string> list, string root, params string[] children)
        {
            if (string.IsNullOrWhiteSpace(root)) return;
            try
            {
                string path = root;
                foreach (string child in children) path = Path.Combine(path, child);
                if (!list.Contains(path, StringComparer.OrdinalIgnoreCase)) list.Add(path);
            }
            catch { }
        }

        private static string PrepareCandidate(string candidate)
        {
            try
            {
                Directory.CreateDirectory(candidate);
                string path = candidate;
                if (!LispTextEncoder.IsAscii(path))
                {
                    path = TryGetShortPath(candidate);
                    if (string.IsNullOrEmpty(path) || !LispTextEncoder.IsAscii(path)) return null;
                }
                string probe = Path.Combine(path, TempPrefix + "write_test.tmp");
                File.WriteAllText(probe, "ok", Encoding.ASCII);
                File.Delete(probe);
                return path;
            }
            catch { return null; }
        }

        private static bool TryGetPid(string file, out int pid)
        {
            pid = 0;
            try
            {
                string name = Path.GetFileNameWithoutExtension(file);
                string[] parts = name.Split('_');
                return parts.Length >= 3 && string.Equals(parts[0], TempPrefix.TrimEnd('_'), StringComparison.OrdinalIgnoreCase) && int.TryParse(parts[1], out pid);
            }
            catch { return false; }
        }

        private static void TryDelete(string path)
        {
            try { if (!string.IsNullOrEmpty(path) && File.Exists(path)) File.Delete(path); }
            catch { }
        }

        private static string TryGetShortPath(string path)
        {
            try
            {
                var buffer = new StringBuilder(1024);
                uint result = GetShortPathName(path, buffer, (uint)buffer.Capacity);
                return result > 0 && result < buffer.Capacity ? buffer.ToString() : null;
            }
            catch { return null; }
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetShortPathName(string lpszLongPath, StringBuilder lpszShortPath, uint cchBuffer);
    }
}
