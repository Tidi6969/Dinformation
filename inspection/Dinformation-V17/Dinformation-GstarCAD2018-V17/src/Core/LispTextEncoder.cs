using System;
using System.Text;

namespace DCAD.Dinformation.Core
{
    internal static class LispTextEncoder
    {
        public static string ToLispStringLiteral(string value)
        {
            if (value == null) value = string.Empty;
            var sb = new StringBuilder(value.Length + 16);
            sb.Append('"');
            foreach (char ch in value)
            {
                if (ch == '"')
                {
                    sb.Append("\\\"");
                }
                else if (ch == '\\')
                {
                    sb.Append("\\\\");
                }
                else if (ch == '\r')
                {
                    sb.Append("\\n");
                }
                else if (ch == '\n')
                {
                    sb.Append("\\n");
                }
                else if (ch == '\t')
                {
                    sb.Append("\\t");
                }
                else if (ch >= 32 && ch <= 126)
                {
                    sb.Append(ch);
                }
                else
                {
                    // The temporary LISP file must remain ASCII.
                    // Two backslashes in source evaluate to one literal backslash,
                    // so the TEXT entity receives CAD's \U+XXXX sequence.
                    sb.Append("\\\\U+");
                    sb.Append(((int)ch).ToString("X4"));
                }
            }
            sb.Append('"');
            return sb.ToString();
        }

        public static string ToAsciiLispPathLiteral(string path)
        {
            string normalized = (path ?? string.Empty).Replace('\\', '/');
            if (!IsAscii(normalized))
                throw new InvalidOperationException("Temporary LISP path is not ASCII: " + normalized);
            return ToLispStringLiteral(normalized);
        }

        public static bool IsAscii(string value)
        {
            if (value == null) return true;
            for (int i = 0; i < value.Length; i++)
                if (value[i] > 127) return false;
            return true;
        }
    }
}
