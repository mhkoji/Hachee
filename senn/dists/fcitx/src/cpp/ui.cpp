#include <fcitx/candidate.h>
#include <fcitx/instance.h>
#include <string>
#include <sstream>

#include "ui.h"

namespace senn {
namespace fcitx {
namespace ui {

namespace {

INPUT_RETURN_VALUE
get_candidate(void* arg, FcitxCandidateWord* word) {
  return IRV_DO_NOTHING;
}

void ShowCandidateWordList(
    FcitxInstance *instance,
    FcitxInputState *input,
    const std::vector<std::string> &word_strings,
    const size_t index) {
  FcitxCandidateWordList *word_list = FcitxInputStateGetCandidateList(input);
  FcitxCandidateWordReset(word_list);
  FcitxCandidateWordSetLayoutHint(word_list, CLH_Vertical);
  std::vector<std::string>::const_iterator it = word_strings.begin();
  for (int i = 0; it != word_strings.end(); ++it, ++i) {
    FcitxCandidateWord word;
    int *p = fcitx_utils_new(int);
    *p = i;
    word.callback = get_candidate;
    word.extraType = MSG_OTHER;
    word.owner = instance;
    word.priv = (void*) p;
    word.strExtra = NULL;
    word.strWord = strdup(it->c_str());
    word.wordType = (i == index) ? MSG_CANDIATE_CURSOR : MSG_OTHER;
    FcitxCandidateWordAppend(word_list, &word);
  }
  // Set page by word index
  FcitxCandidateWordSetFocus(word_list, index);

  FcitxMessages* aux = FcitxInputStateGetAuxUp(input);
  FcitxMessagesSetMessageCount(aux, 0);
  FcitxMessagesAddMessageAtLast(aux, MSG_TIPS, "(%d / %d)",
                                index + 1, word_strings.size());
}

} // namespace

void Show(FcitxInstance *instance,
          const senn::fcitx::views::Converting *converting) {
  // 表示している文字列を削除
  FcitxInstanceCleanInputWindow(instance);

  FcitxInputContext *ic = FcitxInstanceGetCurrentIC(instance);
  FcitxInputState *input = FcitxInstanceGetInputState(instance);
  FcitxMessages *preedit = FcitxInputStateGetPreedit(input);
  FcitxMessages *client_preedit = FcitxInputStateGetClientPreedit(input);
  boolean support_preedit = FcitxInstanceICSupportPreedit(instance, ic);

  // 下線付きの文字列を表示
  {
    int i = 0, cursor_form_index = converting->cursor_form_index;
    std::vector<std::string>::const_iterator it = converting->forms.begin();
    for (; it != converting->forms.end(); ++it, ++i) {
      FcitxMessageType type = (i == cursor_form_index) ?
        (FcitxMessageType) (MSG_HIGHLIGHT | MSG_CANDIATE_CURSOR) :
        (FcitxMessageType) (MSG_INPUT);
      if (!support_preedit) {
        FcitxMessagesAddMessageAtLast(preedit, type, "%s", it->c_str());
      }
      FcitxMessagesAddMessageAtLast(client_preedit, type, "%s", it->c_str());
    }
  }

  if (0 < converting->cursor_form_candidates.size()) {
    ShowCandidateWordList(instance,
                          input,
                          converting->cursor_form_candidates,
                          converting->cursor_form_candidate_index);
  }

  FcitxUIUpdateInputWindow(instance);
}

void Show(FcitxInstance *instance,
          const senn::fcitx::views::Editing *editing) {
  FcitxInputContext *ic = FcitxInstanceGetCurrentIC(instance);

  if (editing->committed_input != "") {
    // 入力を確定
    FcitxInstanceCommitString(instance, ic, editing->committed_input.c_str());
  }

  // 表示している文字列を削除
  FcitxInstanceCleanInputWindow(instance);

  FcitxInputState *input = FcitxInstanceGetInputState(instance);
  FcitxMessages *preedit = FcitxInputStateGetPreedit(input);
  FcitxMessages *client_preedit = FcitxInputStateGetClientPreedit(input);
  boolean support_preedit = FcitxInstanceICSupportPreedit(instance, ic);

  // 下線付きの文字列を表示
  if (!support_preedit) {
    FcitxMessagesAddMessageAtLast(
        preedit, MSG_INPUT, "%s", editing->input.c_str());
  }
  FcitxMessagesAddMessageAtLast(
      client_preedit, MSG_INPUT, "%s", editing->input.c_str());

  if (0 < editing->predictions.size()) {
    ShowCandidateWordList(instance, input, editing->predictions, 0);
  }

  // カーソルの表示
  if (!support_preedit) {
    FcitxInputStateSetCursorPos(input, editing->cursor_pos);
  }
  FcitxInputStateSetClientCursorPos(input, editing->cursor_pos);

  FcitxUIUpdateInputWindow(instance);
}

} // ui
} // fcitx
} // senn
