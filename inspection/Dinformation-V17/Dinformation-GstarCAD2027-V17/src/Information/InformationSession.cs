using System;
using Gssoft.Gscad.ApplicationServices;
using Gssoft.Gscad.EditorInput;
using DCAD.Dinformation.Core;
using DCAD.Dinformation.Data;

namespace DCAD.Dinformation.Information
{
    internal sealed class InformationSession : IDisposable
    {
        private readonly Document _document;
        private readonly Editor _editor;
        private bool _subscribed;
        private bool _forcedPickEnabled;
        private bool _monitorErrorLogged;
        private bool _resetErrorLogged;

        public InformationSession(Document document)
        {
            _document = document ?? throw new ArgumentNullException(nameof(document));
            _editor = document.Editor;
        }

        public void Run()
        {
            ResetLispState();
            Subscribe();
            EnableForcedPick();
            RuntimeLog.Info("Command session started. Drawing=" + (_document.Name ?? string.Empty) + "; Recognition=LISP nentselp/dis; Display=NativePointMonitorTooltip");

            try
            {
                var options = new PromptPointOptions(DCAD.Dinformation.UI.UiText.StartPrompt)
                {
                    AllowNone = true,
                    UseBasePoint = false,
                    UseDashedLine = false
                };
                _editor.GetPoint(options);
            }
            finally
            {
                DisableForcedPick();
                RuntimeLog.Info("Command session ended.");
            }
        }

        private void OnPointMonitor(object sender, PointMonitorEventArgs e)
        {
            try
            {
                if (e == null || e.Context == null) return;
                string tooltip = LispInfoEngine.GetTooltipText(e.Context.RawPoint);
                if (!string.IsNullOrWhiteSpace(tooltip))
                    e.AppendToolTipText(tooltip);
            }
            catch (System.Exception exception)
            {
                if (!_monitorErrorLogged)
                {
                    _monitorErrorLogged = true;
                    RuntimeLog.Error("LISP PointMonitor bridge failed. Further errors in this command are suppressed.", exception);
                }
            }
        }

        private void ResetLispState()
        {
            try { LispInfoEngine.Reset(); }
            catch (System.Exception exception)
            {
                if (!_resetErrorLogged)
                {
                    _resetErrorLogged = true;
                    RuntimeLog.Error("LISP state cleanup failed.", exception);
                }
            }
        }

        private void EnableForcedPick()
        {
            try
            {
                _editor.TurnForcedPickOn();
                _forcedPickEnabled = true;
            }
            catch (System.Exception exception)
            {
                _forcedPickEnabled = false;
                RuntimeLog.Error("TurnForcedPickOn failed. Command continues with PointMonitor cursor feed.", exception);
            }
        }

        private void DisableForcedPick()
        {
            if (!_forcedPickEnabled) return;
            _forcedPickEnabled = false;
            try { _editor.TurnForcedPickOff(); }
            catch (System.Exception exception) { RuntimeLog.Error("TurnForcedPickOff failed.", exception); }
        }

        private void Subscribe()
        {
            if (_subscribed) return;
            _editor.PointMonitor += OnPointMonitor;
            _subscribed = true;
        }

        private void Unsubscribe()
        {
            if (!_subscribed) return;
            _editor.PointMonitor -= OnPointMonitor;
            _subscribed = false;
        }

        public void Dispose()
        {
            Unsubscribe();
            DisableForcedPick();
            ResetLispState();
        }
    }
}
