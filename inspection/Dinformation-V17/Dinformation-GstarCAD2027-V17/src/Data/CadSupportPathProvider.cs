using System;
using System.Globalization;
using GstarApp = Gssoft.Gscad.ApplicationServices.Application;

namespace DCAD.Dinformation.Data
{
    internal static class CadSupportPathProvider
    {
        internal const string HostName = "GstarCAD 2027";
        internal static string ReadSupportPathText()
        {
            try { return Convert.ToString(GstarApp.GetSystemVariable("ACADPREFIX"), CultureInfo.InvariantCulture) ?? string.Empty; }
            catch { return string.Empty; }
        }
        internal static string TryReadProfileName()
        {
            try { return Convert.ToString(GstarApp.GetSystemVariable("CPROFILE"), CultureInfo.InvariantCulture) ?? string.Empty; }
            catch { return string.Empty; }
        }
    }
}
