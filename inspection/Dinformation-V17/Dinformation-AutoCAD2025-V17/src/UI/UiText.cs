using DCAD.Dinformation.Core;

namespace DCAD.Dinformation.UI
{
    internal static class UiText
    {
        public const string CommandName = "Dinformation";
        public static string StartPrompt { get { return "\nDinformation: " + Lang.T("StartPrompt"); } }
        public static string NoDocument { get { return "Dinformation: " + Lang.T("NoDocument"); } }
        public static string ErrorPrefix { get { return "\nDinformation " + Lang.T("ErrorPrefix"); } }
    }
}
