import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: root
    anchors.fill: parent

    property string searchText: ""
    property string filterType: "all"
    property bool isLoading: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        // 1. Search and Filter Row
        RowLayout {
            // This is the key: Don't let the row expand vertically
            Layout.fillWidth: true
            Layout.preferredHeight: 44 
            spacing: Theme.spacingS

            TextField {
                id: searchField
                Layout.fillWidth: true
                Layout.preferredHeight: 44 // Force the box height
                
                placeholderText: "Search anime..."
                verticalAlignment: TextInput.AlignVCenter 
                leftPadding: Theme.spacingL 
                
                color: Theme.surfaceText
                placeholderTextColor: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeMedium

                onTextChanged: root.searchText = text

                background: Rectangle {
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: searchField.activeFocus ? Theme.primary : Theme.outline
                    border.width: 1
                }
            }

            ComboBox {
                id: typeFilter
                Layout.preferredWidth: 100
                Layout.preferredHeight: 44 // Keep it same as TextField
                
                model: ["All", "SUB", "DUB", "RAW"]
                
                contentItem: StyledText {
                    text: typeFilter.displayText
                    color: Theme.surfaceText
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                background: Rectangle {
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: Theme.outline
                    border.width: 1
                }
            }
        }

        // 2. The Spacer / Results Area
        // This Item "eats" all the extra space, pushing the Row to the top
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true 

            LoadingState {
                anchors.centerIn: parent
                visible: root.isLoading
            }
            
            EmptyState {
                anchors.centerIn: parent
                visible: !root.isLoading && root.searchText === "notfound"
            }

            StyledText {
                anchors.centerIn: parent
                text: "Searching for: " + root.searchText
                visible: !root.isLoading && root.searchText.length > 0
                color: Theme.surfaceVariantText
            }
        }
    }
}