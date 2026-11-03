using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using GrxCAD.ApplicationServices;
using DCAD.Dinformation.Data;

namespace DCAD.Dinformation.Core
{
    internal static class LispLauncher
    {
        private const string TemplateSuffix = "Dinformation-GstarCAD2018.lsp.tpl";
        private const string BootstrapMarker = "@@BOOTSTRAP@@";
        private static readonly string[] LispLanguageKeys =
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
            "Yes"
        };

        public static void Start(Document doc)
        {
            if (doc == null) throw new ArgumentNullException("doc");

            CleanupStaleFiles();
            string tempRoot = ResolveWritableAsciiTempRoot(true);
            string fileName = "DINF18_" + Process.GetCurrentProcess().Id + "_" + Guid.NewGuid().ToString("N") + ".lsp";
            string tempFile = Path.Combine(tempRoot, fileName);

            string template = ReadTemplate();
            if (string.IsNullOrEmpty(template) || template.IndexOf(BootstrapMarker, StringComparison.Ordinal) < 0)
                throw new InvalidOperationException(Lang.T("LauncherTemplateMissing"));

            string bootstrap = BuildBootstrap(tempFile);
            string content = template.Replace(BootstrapMarker, bootstrap);
            if (!LispTextEncoder.IsAscii(content))
                throw new InvalidOperationException(Lang.T("LauncherAsciiError"));

            try
            {
                File.WriteAllText(tempFile, content, Encoding.ASCII);
                RuntimeLog.Info("GstarCAD 2018 temporary LISP created: " + tempFile);
                string command = "(load " + LispTextEncoder.ToAsciiLispPathLiteral(tempFile) + ") (dinf18-run) ";
                doc.SendStringToExecute(command, true, false, false);
            }
            catch
            {
                TryDelete(tempFile);
                throw;
            }
        }

        public static void CleanupStaleFiles()
        {
            string root = ResolveWritableAsciiTempRoot(false);
            if (string.IsNullOrEmpty(root) || !Directory.Exists(root)) return;

            int currentPid = Process.GetCurrentProcess().Id;
            string[] files;
            try { files = Directory.GetFiles(root, "DINF18_*.lsp", SearchOption.TopDirectoryOnly); }
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
                catch
                {
                    running = false;
                }

                if (!running) TryDelete(file);
            }
        }

        private static string BuildBootstrap(string tempFile)
        {
            var sb = new StringBuilder();
            sb.Append("(setq *dinf18-temp-file* ").Append(LispTextEncoder.ToAsciiLispPathLiteral(tempFile)).AppendLine(")");
            sb.Append("(setq *dinf18-style* ").Append(LispTextEncoder.ToLispStringLiteral("DINF_U" + Lang.CurrentLanguageId)).AppendLine(")");
            sb.Append("(setq *dinf18-font* ").Append(LispTextEncoder.ToLispStringLiteral(SelectFontFile(Lang.CurrentLanguageId))).AppendLine(")");
            sb.AppendLine("(setq *dinf18-lang* (list");
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
            Assembly assembly = typeof(LispLauncher).Assembly;
            string resource = assembly.GetManifestResourceNames()
                .FirstOrDefault(name => name.EndsWith(TemplateSuffix, StringComparison.OrdinalIgnoreCase));
            if (string.IsNullOrEmpty(resource)) return null;
            using (Stream stream = assembly.GetManifestResourceStream(resource))
            using (var reader = stream == null ? null : new StreamReader(stream, Encoding.ASCII, false))
                return reader == null ? null : reader.ReadToEnd();
        }

        private static string SelectFontFile(int languageId)
        {
            string[] candidates;
            switch (languageId)
            {
                case 2:
                    candidates = new[] { "msyh.ttc", "msyhbd.ttc", "simsun.ttc", "simhei.ttf", "arialuni.ttf", "arial.ttf" };
                    break;
                case 3:
                    candidates = new[] { "meiryo.ttc", "msgothic.ttc", "YuGothM.ttc", "arialuni.ttf", "arial.ttf" };
                    break;
                case 4:
                    candidates = new[] { "malgun.ttf", "malgunbd.ttf", "gulim.ttc", "arialuni.ttf", "arial.ttf" };
                    break;
                case 5:
                    candidates = new[] { "leelawui.ttf", "leelawad.ttf", "tahoma.ttf", "arialuni.ttf", "arial.ttf" };
                    break;
                default:
                    candidates = new[] { "arial.ttf", "tahoma.ttf", "segoeui.ttf" };
                    break;
            }

            string fonts = Environment.GetFolderPath(Environment.SpecialFolder.Fonts);
            foreach (string candidate in candidates)
            {
                try
                {
                    if (!string.IsNullOrEmpty(fonts) && File.Exists(Path.Combine(fonts, candidate)))
                        return candidate;
                }
                catch
                {
                }
            }
            return candidates[candidates.Length - 1];
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
                throw new IOException(Lang.F("LauncherTempError", "No writable ASCII temp directory."));
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
            catch
            {
            }
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

                string probe = Path.Combine(path, "DINF18_write_test.tmp");
                File.WriteAllText(probe, "ok", Encoding.ASCII);
                File.Delete(probe);
                return path;
            }
            catch
            {
                return null;
            }
        }

        private static bool TryGetPid(string file, out int pid)
        {
            pid = 0;
            try
            {
                string name = Path.GetFileNameWithoutExtension(file);
                string[] parts = name.Split('_');
                return parts.Length >= 3 && string.Equals(parts[0], "DINF18", StringComparison.OrdinalIgnoreCase) && int.TryParse(parts[1], out pid);
            }
            catch
            {
                return false;
            }
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
            catch
            {
                return null;
            }
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetShortPathName(string lpszLongPath, StringBuilder lpszShortPath, uint cchBuffer);
    }
}
