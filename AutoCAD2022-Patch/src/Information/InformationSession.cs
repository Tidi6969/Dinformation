using System;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using DCAD.Dinformation.Data;
using DCAD.Dinformation.Core;
using Application = Autodesk.AutoCAD.ApplicationServices.Application;

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
        private bool _nativePickErrorLogged;
        // The native AutoCAD pick context is much cheaper than a LISP nentselp
        // round trip on every pixel of mouse motion.
        private ObjectId _lastPickedId = ObjectId.Null;
        private string _lastTooltip = string.Empty;
        private bool _monitorActive;

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
            RuntimeLog.Info("Command session started. Drawing=" + (_document.Name ?? string.Empty) + "; Recognition=AutoCAD native pick + LISP fallback; Display=NativePointMonitorTooltip");

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
            if (e == null || e.Context == null || _monitorActive) return;

            // PointMonitor events can be very frequent. Avoid nesting callback
            // invocations and do not invoke the LISP reader for an unchanged pick.
            _monitorActive = true;
            try
            {
                ObjectId picked = ObjectId.Null;
                try
                {
                    FullSubentityPath[] paths = e.Context.GetPickedEntities();
                    if (paths != null)
                    {
                        foreach (FullSubentityPath path in paths)
                        {
                            ObjectId[] ids = path.GetObjectIds();
                            if (ids == null || ids.Length == 0) continue;
                            // GC2018 nentselp selects the outer INSERT for a nested
                            // hit, so preserve that behavior rather than inspecting
                            // a hidden block-definition child.
                            ObjectId candidate = ids[0];
                            if (!candidate.IsNull && candidate.IsValid && !candidate.IsErased)
                            {
                                picked = candidate;
                                break;
                            }
                        }
                    }
                }
                catch (System.Exception pickError)
                {
                    // Unsupported custom graphics must not disable the LISP fallback.
                    if (!_nativePickErrorLogged)
                    {
                        _nativePickErrorLogged = true;
                        RuntimeLog.Error("Native AutoCAD picking failed; using LISP fallback.", pickError);
                    }
                }

                if (!picked.IsNull)
                {
                    if (_lastPickedId != picked)
                    {
                        _lastPickedId = picked;
                        _lastTooltip = LispInfoEngine.GetTooltipText(picked.Handle.ToString());
                    }

                    if (!string.IsNullOrWhiteSpace(_lastTooltip))
                    {
                        e.AppendToolTipText(_lastTooltip);
                        return;
                    }
                }

                // Native picking is not guaranteed to include every custom,
                // proxy or nested entity. Never suppress the baseline LISP
                // picker when it is the only recognition path available.
                if (picked.IsNull) _lastPickedId = ObjectId.Null;
                _lastTooltip = LispInfoEngine.GetTooltipText(e.Context.RawPoint);
                if (!string.IsNullOrWhiteSpace(_lastTooltip))
                    e.AppendToolTipText(_lastTooltip);
            }
            catch (System.Exception exception)
            {
                // Do not pin a stale tooltip to a new entity after a failed pick.
                _lastPickedId = ObjectId.Null;
                _lastTooltip = string.Empty;
                if (!_monitorErrorLogged)
                {
                    _monitorErrorLogged = true;
                    RuntimeLog.Error("PointMonitor native pick / LISP reader failed. Further errors in this command are suppressed.", exception);
                }
            }
            finally
            {
                _monitorActive = false;
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
