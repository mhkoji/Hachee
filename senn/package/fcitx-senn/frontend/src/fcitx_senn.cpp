#include <sys/stat.h>
// #include <iostream>

#include <fcitx/ime.h>
#include <fcitx/hook.h>
#include <fcitx/instance.h>
#include <fcitx/context.h>

#include "process/process.h"
#include "senn_fcitx/ui/input.h"
#include "senn_fcitx/im/stateful_ime_proxy_ipc.h"
#include "senn_fcitx/im/stateful_ime_proxy_ipc_server.h"

namespace {

typedef struct _FcitxSennIM {
  FcitxInstance *fcitx;
  FcitxUIMenu menu;

  senn::fcitx::im::StatefulIMEProxyIPC *ime;
  senn::fcitx::im::StatefulIMEProxyIPCServerLauncher *launcher;
} FcitxSennIM;

} // namespace

namespace senn {
namespace fcitx_senn_im {
namespace menu {

const char* GetIconName(void* arg) {
  return "";
}

void Update(FcitxUIMenu *menu) {}

boolean Action(FcitxUIMenu *menu, int index) {
  return senn::process::Spawn("/usr/lib/senn/menu-about");
}

void SetVisibility(FcitxInstance *fcitx, boolean vis) {
  FcitxUISetStatusVisable(fcitx, "senn-menu", vis);
}

void Setup(FcitxInstance *fcitx, FcitxUIMenu *menu) {
  FcitxUIRegisterComplexStatus(
      fcitx,
      NULL,
      "senn-menu",
      "メニュー",
      "メニュー",
      NULL,
      GetIconName);

  FcitxMenuInit(menu);
  menu->name = strdup("メニュー");
  menu->candStatusBind = strdup("senn-menu");
  menu->UpdateMenu = Update;
  menu->MenuAction = Action;
  menu->priv = nullptr;
  menu->isSubMenu = false;
  FcitxMenuAddMenuItem(menu, "Senn について", MENUTYPE_SIMPLE, NULL);
  FcitxUIRegisterMenu(fcitx, menu);

  SetVisibility(fcitx, false);
}

void Destory(FcitxInstance *fcitx, FcitxUIMenu *menu) {
  FcitxUIUnRegisterMenu(fcitx, menu);
  fcitx_utils_free(menu->name);
  fcitx_utils_free(menu->candStatusBind);
  FcitxMenuFinalize(menu);
}

} // menu

static void ResetInput(void *arg) {
  FcitxSennIM *senn = (FcitxSennIM *)arg;
  FcitxInstance *instance = senn->fcitx;

  FcitxIM *im = FcitxInstanceGetCurrentIM(instance);
  if (im && strcmp(im->uniqueName, "senn") == 0) {
    menu::SetVisibility(instance, true);
  } else {
    menu::SetVisibility(instance, false);
  }
}


void ResetIM(void *arg) {
  FcitxSennIM *senn = (FcitxSennIM *)arg;
  FcitxInstance *instance = senn->fcitx;

  senn->ime->ResetIM();

  senn::fcitx::im::views::Editing editing_view;
  editing_view.input = "";
  editing_view.cursor_pos = 0;
  senn::fcitx::ui::input::Show(instance, &editing_view);
}


boolean Init(void *arg) {
  FcitxSennIM *senn_im = (FcitxSennIM *)arg;

  boolean flag = true;
  FcitxInstanceSetContext(senn_im->fcitx,
                          CONTEXT_IM_KEYBOARD_LAYOUT,
                          "jp");
  FcitxInstanceSetContext(senn_im->fcitx,
                          CONTEXT_DISABLE_AUTO_FIRST_CANDIDATE_HIGHTLIGHT,
                          &flag);
  FcitxInstanceSetContext(senn_im->fcitx,
                          CONTEXT_DISABLE_AUTOENG,
                          &flag);
  FcitxInstanceSetContext(senn_im->fcitx,
                          CONTEXT_DISABLE_QUICKPHRASE,
                          &flag);

  // std::cout << "senn-fcitx: initialized:"
  //           << " [" << std::hex << arg << "]"
  //           << std::endl;

  return true;
}


INPUT_RETURN_VALUE DoInput(void *arg,
                           FcitxKeySym _sym,
                           uint32_t _state) {
  FcitxSennIM *senn = (FcitxSennIM *)arg;
  FcitxInstance *instance = senn->fcitx;
  FcitxInputState *input = FcitxInstanceGetInputState(instance);

  FcitxKeySym sym = (FcitxKeySym) FcitxInputStateGetKeySym(input);
  uint32_t keycode = FcitxInputStateGetKeyCode(input);
  uint32_t state = FcitxInputStateGetKeyState(input);
  // std::cout << sym << " " << keycode << " " << state << std::endl;

  return senn->ime->ProcessInput(sym, keycode, state,
    [&](const senn::fcitx::im::views::Converting *view) {
      senn::fcitx::ui::input::Show(instance, view);
    },

    [&](const senn::fcitx::im::views::Editing *view) {
      senn::fcitx::ui::input::Show(instance, view);
    });
}

INPUT_RETURN_VALUE DoReleaseInput(void *arg,
                                  FcitxKeySym sym,
                                  uint32_t state) {
  return IRV_TO_PROCESS;
}


void ReloadConfig(void *arg) {
}

} // fcitx_senn_im
} // senn


static void FcitxSennDestroy(void *arg) {
  FcitxSennIM *senn_im = (FcitxSennIM *)arg;

  delete senn_im->ime;
  delete senn_im->launcher;

  senn::fcitx_senn_im::menu::Destory(senn_im->fcitx, &senn_im->menu);

  free(senn_im);

  // std::cout << "senn-fcitx: destroyed:"
  //           << " [" << std::hex << arg << "]"
  //           << std::endl;
}

static void* FcitxSennCreate(FcitxInstance *fcitx) {
  FcitxSennIM *senn_im =
    (FcitxSennIM*) fcitx_utils_malloc0(sizeof(FcitxSennIM));

  senn_im->fcitx = fcitx;

  // StatefulIME
  senn_im->launcher =
    new senn::fcitx::im::StatefulIMEProxyIPCServerLauncher(
      "/usr/lib/senn/server");
  senn_im->launcher->Spawn();

  senn_im->ime =
    new senn::fcitx::im::StatefulIMEProxyIPC(
      std::unique_ptr<senn::ipc::RequesterInterface>(
        new senn::fcitx::im::ReconnectableStatefulIMERequester(
          senn_im->launcher)));

  FcitxIMEventHook hk;
  hk.arg = senn_im;
  hk.func = senn::fcitx_senn_im::ResetInput;
  FcitxInstanceRegisterResetInputHook(fcitx, hk);
  
  // Menu
  senn::fcitx_senn_im::menu::Setup(senn_im->fcitx, &senn_im->menu);

  // Register
  FcitxIMIFace iface;
  memset(&iface, 0, sizeof(FcitxIMIFace));
  iface.Init           = senn::fcitx_senn_im::Init;
  iface.ResetIM        = senn::fcitx_senn_im::ResetIM;
  iface.DoInput        = senn::fcitx_senn_im::DoInput;
  iface.DoReleaseInput = senn::fcitx_senn_im::DoReleaseInput;
  iface.ReloadConfig   = senn::fcitx_senn_im::ReloadConfig;
  FcitxInstanceRegisterIMv2(
      fcitx,
      senn_im,
      "senn",
      "Senn",
      "senn",
      iface,
      10,
      "ja"
  );

  // std::cout << "senn-fcitx: created:"
  //           << " [" << std::hex << senn << "]"
  //           << std::endl;

  return senn_im;
}

extern "C" {

FCITX_EXPORT_API
FcitxIMClass ime = {
  FcitxSennCreate,
  FcitxSennDestroy
};

FCITX_EXPORT_API
int ABI_VERSION = FCITX_ABI_VERSION;

} // extern "C"
