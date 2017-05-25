﻿using System;
using System.Collections.Generic;
using UnityEngine.MaterialGraph;
using RMGUI.GraphView;
using UnityEditor.Graphing.Drawing;

namespace UnityEditor.MaterialGraph.Drawing
{
    [Serializable]
    class MatrixCommonContolPresenter : GraphControlPresenter
    {

        private string[] m_MatrixTypeNames;
        private string[] matrixTypeNames
        {
            get
            {
                if (m_MatrixTypeNames == null)
                    m_MatrixTypeNames = Enum.GetNames(typeof(CommonMatrixType));
                return m_MatrixTypeNames;
            }
        }

        public override void OnGUIHandler()
        {
            base.OnGUIHandler();

            var cNode = node as UnityEngine.MaterialGraph.MatrixCommonNode;
            if (cNode == null)
                return;

            cNode.matrix = (CommonMatrixType)EditorGUILayout.Popup((int)cNode.matrix, matrixTypeNames, EditorStyles.popup);
        }

        public override float GetHeight()
        {
            return EditorGUIUtility.singleLineHeight + EditorGUIUtility.standardVerticalSpacing;
        }
    }

    [Serializable]
    public class MatrixCommonNodePresenter : MaterialNodePresenter
    {
        protected override IEnumerable<GraphElementPresenter> GetControlData()
        {
            var instance = CreateInstance<MatrixCommonContolPresenter>();
            instance.Initialize(node);
            return new List<GraphElementPresenter> { instance };
        }
    }
}
