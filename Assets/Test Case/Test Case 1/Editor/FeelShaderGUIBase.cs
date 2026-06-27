using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace FeelToon.ShaderInspector
{
    public abstract class FeelShaderGUIBase : ShaderGUI
    {
        protected MaterialEditor materialEditor;
        protected MaterialProperty[] properties;
        protected Material targetMat;

        private const string PrefsPrefix = "FeelToon.Foldout.";
        private static readonly Dictionary<string, bool> foldoutCache = new Dictionary<string, bool>();

        private static GUIStyle _bodyBoxStyle;
        protected static GUIStyle BodyBoxStyle
        {
            get
            {
                if (_bodyBoxStyle == null || _bodyBoxStyle.normal.background == null)
                {
                    var tex = new Texture2D(1, 1) { hideFlags = HideFlags.DontSave };
                    tex.SetPixel(0, 0, BodyBg);
                    tex.Apply();
                    _bodyBoxStyle = new GUIStyle
                    {
                        normal = { background = tex },
                        padding = new RectOffset(4, 4, 6, 6)
                    };
                }
                return _bodyBoxStyle;
            }
        }

        public override void OnGUI(MaterialEditor matEditor, MaterialProperty[] props)
        {
            materialEditor = matEditor;
            properties = props;
            targetMat = matEditor.target as Material;

            DrawTitleBar();
            DrawSections();
            EditorGUILayout.Space(10);
            DrawFooter();
        }

        protected abstract void DrawSections();

        protected virtual void DrawTitleBar()
        {
            EditorGUILayout.Space(4);
            var rect = EditorGUILayout.GetControlRect(false, 28);
            EditorGUI.DrawRect(rect, new Color(0.15f, 0.15f, 0.18f, 1f));
            var style = new GUIStyle(EditorStyles.boldLabel)
            {
                normal = { textColor = new Color(0.95f, 0.95f, 0.95f) },
                fontSize = 13,
                alignment = TextAnchor.MiddleLeft,
                padding = new RectOffset(10, 10, 0, 0)
            };
            var shaderName = targetMat != null && targetMat.shader != null ? targetMat.shader.name : "";
            GUI.Label(rect, shaderName, style);
            EditorGUILayout.Space(4);
        }

        protected virtual void DrawFooter()
        {
            materialEditor.RenderQueueField();
            materialEditor.EnableInstancingField();
            materialEditor.DoubleSidedGIField();
        }

        // ------------- Helpers -------------

        protected MaterialProperty Find(string name)
        {
            return FindProperty(name, properties, false);
        }

        protected void Prop(string name, string label = null)
        {
            var p = Find(name);
            if (p == null) return;
            var content = label != null
                ? new GUIContent(label)
                : new GUIContent(p.displayName);
            materialEditor.ShaderProperty(p, content);
        }

        protected void Tex(string name, string label = null)
        {
            var p = Find(name);
            if (p == null) return;
            var content = label != null
                ? new GUIContent(label)
                : new GUIContent(p.displayName);
            materialEditor.TexturePropertySingleLine(content, p);
        }

        // Color palette
        private static readonly Color GroupBg     = new Color(0.13f, 0.13f, 0.15f, 1f);
        private static readonly Color GroupAccent = new Color(0.42f, 0.58f, 0.95f, 1f);
        private static readonly Color SectionBg   = new Color(0.22f, 0.22f, 0.24f, 1f);
        private static readonly Color SectionBgHover = new Color(0.28f, 0.28f, 0.31f, 1f);
        private static readonly Color SectionBorder = new Color(0.10f, 0.10f, 0.12f, 1f);
        private static readonly Color BodyBg      = new Color(0.19f, 0.19f, 0.21f, 1f);

        // Sub-header: small bold label + underline, used inside a section body
        // to separate logical sub-blocks (e.g. Primary Band / Secondary Band).
        protected void DrawSubHeader(string title)
        {
            EditorGUILayout.Space(4);
            var rect = EditorGUILayout.GetControlRect(false, 16);
            var labelStyle = new GUIStyle(EditorStyles.miniBoldLabel)
            {
                fontSize = 11,
                normal = { textColor = new Color(0.78f, 0.82f, 0.92f) },
                alignment = TextAnchor.MiddleLeft
            };
            GUI.Label(new Rect(rect.x + 2, rect.y, rect.width - 2, rect.height), title, labelStyle);
            EditorGUI.DrawRect(new Rect(rect.x, rect.yMax - 1, rect.width, 1),
                               new Color(0.35f, 0.35f, 0.38f, 1f));
            EditorGUILayout.Space(2);
        }

        // Big group: top-level visual divider, always shown (not collapsible).
        protected void DrawBigGroup(string title, Action body)
        {
            EditorGUILayout.Space(10);

            var rect = EditorGUILayout.GetControlRect(false, 26);
            EditorGUI.DrawRect(rect, GroupBg);
            // left accent bar
            EditorGUI.DrawRect(new Rect(rect.x, rect.y, 4, rect.height), GroupAccent);

            var labelStyle = new GUIStyle(EditorStyles.boldLabel)
            {
                normal = { textColor = Color.white },
                alignment = TextAnchor.MiddleLeft,
                padding = new RectOffset(14, 10, 0, 0),
                fontSize = 14
            };
            GUI.Label(rect, title, labelStyle);

            EditorGUILayout.Space(4);
            body();
        }

        // Section: collapsible foldout with optional toggle property as first row inside.
        // toggleProp can be null (always-on section).
        protected void DrawSection(string title, string toggleProp, Action body)
        {
            string key = PrefsPrefix + "S." + title;
            bool open = GetFoldout(key, false);

            // Header row (clickable card)
            var headerRect = EditorGUILayout.GetControlRect(false, 22);
            var hovering = headerRect.Contains(Event.current.mousePosition);
            EditorGUI.DrawRect(headerRect, hovering ? SectionBgHover : SectionBg);
            // bottom hairline
            EditorGUI.DrawRect(
                new Rect(headerRect.x, headerRect.yMax - 1, headerRect.width, 1),
                SectionBorder);

            // arrow
            var arrowStyle = new GUIStyle(EditorStyles.label)
            {
                fontSize = 10,
                normal = { textColor = new Color(0.85f, 0.85f, 0.85f) },
                alignment = TextAnchor.MiddleCenter
            };
            GUI.Label(new Rect(headerRect.x + 6, headerRect.y, 14, headerRect.height),
                      open ? "▼" : "▶", arrowStyle);

            // title
            var titleStyle = new GUIStyle(EditorStyles.boldLabel)
            {
                normal = { textColor = new Color(0.92f, 0.92f, 0.92f) },
                alignment = TextAnchor.MiddleLeft
            };
            GUI.Label(new Rect(headerRect.x + 24, headerRect.y, headerRect.width - 28, headerRect.height),
                      title, titleStyle);

            // whole row click
            if (Event.current.type == EventType.MouseDown && hovering && Event.current.button == 0)
            {
                open = !open;
                SetFoldout(key, open);
                Event.current.Use();
                GUI.changed = true;
            }
            else if (Event.current.type == EventType.MouseMove && hovering)
            {
                GUI.changed = true; // trigger repaint for hover
            }

            if (!open)
            {
                EditorGUILayout.Space(2);
                return;
            }

            // Body — wrapped in a tinted box via GUIStyle background (drawn before contents).
            EditorGUILayout.BeginVertical(BodyBoxStyle);

            MaterialProperty toggle = toggleProp != null ? Find(toggleProp) : null;
            if (toggle != null)
            {
                materialEditor.ShaderProperty(toggle, toggle.displayName);
                using (new EditorGUI.DisabledScope(toggle.floatValue < 0.5f))
                {
                    body();
                }
            }
            else
            {
                body();
            }

            EditorGUILayout.EndVertical();
            EditorGUILayout.Space(3);
        }

        // ------------- Foldout state -------------

        protected bool GetFoldout(string key, bool defaultValue)
        {
            if (foldoutCache.TryGetValue(key, out var v)) return v;
            v = EditorPrefs.GetBool(key, defaultValue);
            foldoutCache[key] = v;
            return v;
        }

        protected void SetFoldout(string key, bool value)
        {
            foldoutCache[key] = value;
            EditorPrefs.SetBool(key, value);
        }
    }
}
