using System;
using System.Collections.Generic;
using System.Linq;
using UnityEditor.Experimental.UIElements.GraphView;
using UnityEditor.MaterialGraph.Drawing;
using UnityEditor.MaterialGraph.Drawing.Inspector;
using UnityEngine;
using UnityEngine.Experimental.UIElements;
using UnityEngine.MaterialGraph;
using UnityEngine.Graphing;
using Object = UnityEngine.Object;

namespace UnityEditor.MaterialGraph.Drawing
{
    public class GraphEditorView : VisualElement, IDisposable
    {
        AbstractMaterialGraph m_Graph;
        MaterialGraphView m_GraphView;
        GraphInspectorView m_GraphInspectorView;
        ToolbarView m_ToolbarView;
        ToolbarButtonView m_TimeButton;
        ToolbarButtonView m_CopyToClipboardButton;

        PreviewSystem m_PreviewSystem;

        [SerializeField]
        MaterialGraphPresenter m_GraphPresenter;

        public Action onUpdateAssetClick { get; set; }
        public Action onConvertToSubgraphClick { get; set; }
        public Action onShowInProjectClick { get; set; }

        public MaterialGraphView graphView
        {
            get { return m_GraphView; }
        }

        public PreviewRate previewRate
        {
            get { return previewSystem.previewRate; }
            set { previewSystem.previewRate = value; }
        }

        public MaterialGraphPresenter graphPresenter
        {
            get { return m_GraphPresenter; }
            set { m_GraphPresenter = value; }
        }

        public PreviewSystem previewSystem
        {
            get { return m_PreviewSystem; }
            set { m_PreviewSystem = value; }
        }

        public GraphEditorView(AbstractMaterialGraph graph, string assetName)
        {
            m_Graph = graph;
            AddStyleSheetPath("Styles/MaterialGraph");

            previewSystem = new PreviewSystem(graph);

            m_ToolbarView = new ToolbarView { name = "TitleBar" };
            {
                m_ToolbarView.Add(new ToolbarSpaceView());
                m_ToolbarView.Add(new ToolbarSeparatorView());

                var updateAssetButton = new ToolbarButtonView { text = "Update asset" };
                updateAssetButton.AddManipulator(new Clickable(() =>
                {
                    if (onUpdateAssetClick != null) onUpdateAssetClick();
                }));
                m_ToolbarView.Add(updateAssetButton);

                m_ToolbarView.Add(new ToolbarSeparatorView());
                m_ToolbarView.Add(new ToolbarSpaceView());
                m_ToolbarView.Add(new ToolbarSeparatorView());

                var convertToSubgraphButton = new ToolbarButtonView { text = "Convert to subgraph" };
                convertToSubgraphButton.AddManipulator(new Clickable(() =>
                {
                    if (onConvertToSubgraphClick != null) onConvertToSubgraphClick();
                }));
                m_ToolbarView.Add(convertToSubgraphButton);

                m_ToolbarView.Add(new ToolbarSeparatorView());
                m_ToolbarView.Add(new ToolbarSpaceView());
                m_ToolbarView.Add(new ToolbarSeparatorView());

                var showInProjectButton = new ToolbarButtonView { text = "Show in project" };
                showInProjectButton.AddManipulator(new Clickable(() =>
                {
                    if (onShowInProjectClick != null) onShowInProjectClick();
                }));
                m_ToolbarView.Add(showInProjectButton);

                m_ToolbarView.Add(new ToolbarSeparatorView());
                m_ToolbarView.Add(new ToolbarSpaceView());
                m_ToolbarView.Add(new ToolbarSeparatorView());

                m_TimeButton = new ToolbarButtonView { text = "Preview rate: " + previewRate };
                m_TimeButton.AddManipulator(new Clickable(() =>
                {
                    if (previewRate == PreviewRate.Full)
                        previewRate = PreviewRate.Throttled;
                    else if (previewRate == PreviewRate.Throttled)
                        previewRate = PreviewRate.Off;
                    else if (previewRate == PreviewRate.Off)
                        previewRate = PreviewRate.Full;
                    m_TimeButton.text = "Preview rate: " + previewRate;
                }));
                m_ToolbarView.Add(m_TimeButton);

                m_ToolbarView.Add(new ToolbarSeparatorView());

                m_CopyToClipboardButton = new ToolbarButtonView() { text = "Copy shader to clipboard" };
                m_CopyToClipboardButton.AddManipulator(new Clickable(() =>
                    {
                        AbstractMaterialNode masterNode = graph.GetNodes<MasterNode>().First();
                        var textureInfo = new List<PropertyCollector.TextureInfo>();
                        PreviewMode previewMode;
                        string shader = graph.GetShader(masterNode, GenerationMode.ForReals, assetName, out textureInfo, out previewMode);
                        GUIUtility.systemCopyBuffer = shader;
                    }
                ));

                m_ToolbarView.Add(m_CopyToClipboardButton);

                m_ToolbarView.Add(new ToolbarSeparatorView());
            }
            Add(m_ToolbarView);

            m_GraphPresenter = new MaterialGraphPresenter();

            var content = new VisualElement { name = "content" };
            {
                m_GraphView = new MaterialGraphView(graph) { name = "GraphView" };
                m_GraphView.SetupZoom(ContentZoomer.DefaultMinScale, ContentZoomer.DefaultMaxScale);
                m_GraphView.AddManipulator(new ContentDragger());
                m_GraphView.AddManipulator(new RectangleSelector());
                m_GraphView.AddManipulator(new SelectionDragger());
                m_GraphView.AddManipulator(new ClickSelector());
                m_GraphView.AddManipulator(new NodeCreator(graph));
                content.Add(m_GraphView);

                m_GraphInspectorView = new GraphInspectorView(assetName, previewSystem, graph) { name = "inspector" };
                m_GraphView.onSelectionChanged += m_GraphInspectorView.UpdateSelection;
                content.Add(m_GraphInspectorView);

                m_GraphView.graphViewChanged = GraphViewChanged;
            }

            m_GraphPresenter.Initialize(m_GraphView, graph, previewSystem);

            Add(content);
        }

        GraphViewChange GraphViewChanged(GraphViewChange graphViewChange)
        {
            if (graphViewChange.edgesToCreate != null)
            {
                foreach (var edge in graphViewChange.edgesToCreate)
                {
                    m_Graph.owner.RegisterCompleteObjectUndo("Connect Edge");
                    var leftSlot = edge.output.userData as ISlot;
                    var rightSlot = edge.input.userData as ISlot;
                    if (leftSlot != null && rightSlot != null)
                        m_Graph.Connect(leftSlot.slotReference, rightSlot.slotReference);
                }
                graphViewChange.edgesToCreate.Clear();
            }

            if (graphViewChange.movedElements != null)
            {
                foreach (var element in graphViewChange.movedElements)
                {
                    var node = element.userData as INode;
                    if (node == null)
                        continue;

                    var drawState = node.drawState;
                    drawState.position = element.layout;
                    node.drawState = drawState;
                }
            }

            return graphViewChange;
        }

        public void Dispose()
        {
            onUpdateAssetClick = null;
            onConvertToSubgraphClick = null;
            onShowInProjectClick = null;
            if (m_GraphInspectorView != null) m_GraphInspectorView.Dispose();
            if (previewSystem != null)
            {
                previewSystem.Dispose();
                previewSystem = null;
            }
        }
    }
}
