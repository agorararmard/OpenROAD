#pragma once

#include <memory>

#include "gui/gui.h"
#include "frBaseTypes.h"

namespace odb {
  class dbDatabase;
}

namespace fr {

class frPoint;
class FlexGridGraph;
class FlexWavefrontGrid;
class FlexDRWorker;
class drNet;
class frDesign;

// This class draws debugging graphics on the layout
class FlexDRGraphics : public gui::Renderer
{
 public:
  // Debug InitialPlace
  FlexDRGraphics(frDebugSettings* settings, frDesign* design, odb::dbDatabase* db);

  void startWorker(FlexDRWorker* worker);

  void startIter(int iter);

  void startNet(drNet* net);

  void endNet(drNet* net);

  void searchNode(const FlexGridGraph* grid_graph,
                  const FlexWavefrontGrid& grid);

  // Show a message in the status bar
  void status(const std::string& message);

  // From Renderer API
  virtual void drawObjects(gui::Painter& painter) override;
  virtual void drawLayer(odb::dbTechLayer* layer, gui::Painter& painter) override;

  // Is the GUI being displayed (true) or are we in batch mode (false)
  static bool guiActive();

 private:
  FlexDRWorker*    worker_;
  drNet*           net_;
  const FlexGridGraph* grid_graph_;
  frDebugSettings* settings_;
  int              current_iter_;
  frLayerNum       last_pt_layer_;
  gui::Gui*        gui_;
  // maps odb layerIdx -> tr layerIdx, with -1 for no equivalent
  std::vector<frLayerNum> layer_map_;
  std::vector<std::vector<frPoint>> points_by_layer_;
};

}  // namespace dr
