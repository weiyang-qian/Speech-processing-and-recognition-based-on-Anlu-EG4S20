---
license: other
license_name: model-license
license_link: https://github.com/alibaba-damo-academy/FunASR/blob/main
tasks:
- voice-activity-detection
pipeline_tag: voice-activity-detection
---


# FunASR: A Fundamental End-to-End Speech Recognition Toolkit


[![PyPI](https://img.shields.io/pypi/v/funasr)](https://pypi.org/project/funasr/)


<strong>FunASR</strong> hopes to build a bridge between academic research and industrial applications on speech recognition. By supporting the training & finetuning of the industrial-grade speech recognition model, researchers and developers can conduct research and production of speech recognition models more conveniently, and promote the development of speech recognition ecology. ASR for Fun！

[**Highlights**](#highlights)
| [**News**](https://github.com/alibaba-damo-academy/FunASR#whats-new) 
| [**Installation**](#installation)
| [**Quick Start**](#quick-start)
| [**Runtime**](./runtime/readme.md)
| [**Model Zoo**](#model-zoo)
| [**Contact**](#contact)


<a name="highlights"></a>
## Highlights
- FunASR is a fundamental speech recognition toolkit that offers a variety of features, including speech recognition (ASR), Voice Activity Detection (VAD), Punctuation Restoration, Language Models, Speaker Verification, Speaker Diarization and multi-talker ASR. FunASR provides convenient scripts and tutorials, supporting inference and fine-tuning of pre-trained models.
- We have released a vast collection of academic and industrial pretrained models on the [ModelScope](https://www.modelscope.cn/models?page=1&tasks=auto-speech-recognition) and [huggingface](https://huggingface.co/FunASR), which can be accessed through our [Model Zoo](https://github.com/alibaba-damo-academy/FunASR/blob/main/docs/model_zoo/modelscope_models.md). The representative [Paraformer-large](https://www.modelscope.cn/models/damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-pytorch/summary), a non-autoregressive end-to-end speech recognition model, has the advantages of high accuracy, high efficiency, and convenient deployment, supporting the rapid construction of speech recognition services. For more details on service deployment, please refer to the [service deployment document](runtime/readme_cn.md). 


<a name="Installation"></a>
## Installation

```shell
pip3 install -U funasr
```
Or install from source code
``` sh
git clone https://github.com/alibaba/FunASR.git && cd FunASR
pip3 install -e ./
```
Install modelscope for the pretrained models (Optional)

```shell
pip3 install -U modelscope
```

## Model Zoo
FunASR has open-sourced a large number of pre-trained models on industrial data. You are free to use, copy, modify, and share FunASR models under the [Model License Agreement](./MODEL_LICENSE). Below are some representative models, for more models please refer to the [Model Zoo]().

(Note: 🤗 represents the Huggingface model zoo link, ⭐ represents the ModelScope model zoo link)


|                                                                             Model Name                                                                             |                    Task Details                    |          Training Data           | Parameters |
|:------------------------------------------------------------------------------------------------------------------------------------------------------------------:|:--------------------------------------------------:|:--------------------------------:|:----------:|
|    paraformer-zh <br> ([⭐](https://www.modelscope.cn/models/damo/speech_paraformer-large-vad-punc_asr_nat-zh-cn-16k-common-vocab8404-pytorch/summary)  [🤗]() )    | speech recognition, with timestamps, non-streaming |      60000 hours, Mandarin       |    220M    |
| <nobr>paraformer-zh-streaming <br> ( [⭐](https://modelscope.cn/models/damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-online/summary) [🤗]() )</nobr> |           speech recognition, streaming            |      60000 hours, Mandarin       |    220M    |
|         paraformer-en <br> ( [⭐](https://www.modelscope.cn/models/damo/speech_paraformer-large-vad-punc_asr_nat-en-16k-common-vocab10020/summary) [🤗]() )         | speech recognition, with timestamps, non-streaming |       50000 hours, English       |    220M    |
|                     conformer-en <br> ( [⭐](https://modelscope.cn/models/damo/speech_conformer_asr-en-16k-vocab4199-pytorch/summary) [🤗]() )                      |         speech recognition, non-streaming          |       50000 hours, English       |    220M    |
|                     ct-punc <br> ( [⭐](https://modelscope.cn/models/damo/punc_ct-transformer_cn-en-common-vocab471067-large/summary) [🤗]() )                      |              punctuation restoration               |    100M, Mandarin and English    |    1.1G    | 
|                          fsmn-vad <br> ( [⭐](https://modelscope.cn/models/damo/speech_fsmn_vad_zh-cn-16k-common-pytorch/summary) [🤗]() )                          |              voice activity detection              | 5000 hours, Mandarin and English |    0.4M    | 
|                          fa-zh <br> ( [⭐](https://modelscope.cn/models/damo/speech_timestamp_prediction-v1-16k-offline/summary) [🤗]() )                           |                timestamp prediction                |       5000 hours, Mandarin       |    38M     | 
|                cam++ <br> ( [⭐](https://modelscope.cn/models/iic/speech_campplus_sv_zh-cn_16k-common/summary) [🤗]() )                                             |        speaker verification/diarization            |            5000 hours            |    7.2M    | 




[//]: # ()
[//]: # (FunASR supports pre-trained or further fine-tuned models for deployment as a service. The CPU version of the Chinese offline file conversion service has been released, details can be found in [docs]&#40;funasr/runtime/docs/SDK_tutorial.md&#41;. More detailed information about service deployment can be found in the [deployment roadmap]&#40;funasr/runtime/readme_cn.md&#41;.)


<a name="quick-start"></a>
## Quick Start

Below is a quick start tutorial. Test audio files ([Mandarin](https://isv-data.oss-cn-hangzhou.aliyuncs.com/ics/MaaS/ASR/test_audio/vad_example.wav), [English]()).

### Command-line usage

```shell
funasr +model=paraformer-zh +vad_model="fsmn-vad" +punc_model="ct-punc" +input=asr_example_zh.wav
```

Notes: Support recognition of single audio file, as well as file list in Kaldi-style wav.scp format: `wav_id wav_pat`

### Speech Recognition (Non-streaming)
```python
from funasr import AutoModel
# paraformer-zh is a multi-functional asr model
# use vad, punc, spk or not as you need
model = AutoModel(model="paraformer-zh", model_revision="v2.0.4",
                  vad_model="fsmn-vad", vad_model_revision="v2.0.4",
                  punc_model="ct-punc-c", punc_model_revision="v2.0.4",
                  # spk_model="cam++", spk_model_revision="v2.0.2",
                  )
res = model.generate(input=f"{model.model_path}/example/asr_example.wav", 
                     batch_size_s=300, 
                     hotword='魔搭')
print(res)
```
Note: `model_hub`: represents the model repository, `ms` stands for selecting ModelScope download, `hf` stands for selecting Huggingface download.

### Speech Recognition (Streaming)
```python
from funasr import AutoModel

chunk_size = [0, 10, 5] #[0, 10, 5] 600ms, [0, 8, 4] 480ms
encoder_chunk_look_back = 4 #number of chunks to lookback for encoder self-attention
decoder_chunk_look_back = 1 #number of encoder chunks to lookback for decoder cross-attention

model = AutoModel(model="paraformer-zh-streaming", model_revision="v2.0.4")

import soundfile
import os

wav_file = os.path.join(model.model_path, "example/asr_example.wav")
speech, sample_rate = soundfile.read(wav_file)
chunk_stride = chunk_size[1] * 960 # 600ms

cache = {}
total_chunk_num = int(len((speech)-1)/chunk_stride+1)
for i in range(total_chunk_num):
    speech_chunk = speech[i*chunk_stride:(i+1)*chunk_stride]
    is_final = i == total_chunk_num - 1
    res = model.generate(input=speech_chunk, cache=cache, is_final=is_final, chunk_size=chunk_size, encoder_chunk_look_back=encoder_chunk_look_back, decoder_chunk_look_back=decoder_chunk_look_back)
    print(res)
```
Note: `chunk_size` is the configuration for streaming latency.` [0,10,5]` indicates that the real-time display granularity is `10*60=600ms`, and the lookahead information is `5*60=300ms`. Each inference input is `600ms` (sample points are `16000*0.6=960`), and the output is the corresponding text. For the last speech segment input, `is_final=True` needs to be set to force the output of the last word.

### Voice Activity Detection (Non-Streaming)
```python
from funasr import AutoModel

model = AutoModel(model="fsmn-vad", model_revision="v2.0.4")
wav_file = f"{model.model_path}/example/asr_example.wav"
res = model.generate(input=wav_file)
print(res)
```
### Voice Activity Detection (Streaming)
```python
from funasr import AutoModel

chunk_size = 200 # ms
model = AutoModel(model="fsmn-vad", model_revision="v2.0.4")

import soundfile

wav_file = f"{model.model_path}/example/vad_example.wav"
speech, sample_rate = soundfile.read(wav_file)
chunk_stride = int(chunk_size * sample_rate / 1000)

cache = {}
total_chunk_num = int(len((speech)-1)/chunk_stride+1)
for i in range(total_chunk_num):
    speech_chunk = speech[i*chunk_stride:(i+1)*chunk_stride]
    is_final = i == total_chunk_num - 1
    res = model.generate(input=speech_chunk, cache=cache, is_final=is_final, chunk_size=chunk_size)
    if len(res[0]["value"]):
        print(res)
```
### Punctuation Restoration
```python
from funasr import AutoModel

model = AutoModel(model="ct-punc", model_revision="v2.0.4")
res = model.generate(input="那今天的会就到这里吧 happy new year 明年见")
print(res)
```
### Timestamp Prediction
```python
from funasr import AutoModel

model = AutoModel(model="fa-zh", model_revision="v2.0.4")
wav_file = f"{model.model_path}/example/asr_example.wav"
text_file = f"{model.model_path}/example/text.txt"
res = model.generate(input=(wav_file, text_file), data_type=("sound", "text"))
print(res)
```

More examples ref to [docs](https://github.com/alibaba-damo-academy/FunASR/tree/main/examples/industrial_data_pretraining)
