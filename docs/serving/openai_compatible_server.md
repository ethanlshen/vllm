# OpenAI-Compatible Server

vLLM provides an HTTP server that implements OpenAI's [Completions API](https://platform.openai.com/docs/api-reference/completions), [Chat API](https://platform.openai.com/docs/api-reference/chat), and more! This functionality lets you serve models and interact with them using an HTTP client.

In your terminal, you can [install](../getting_started/installation/README.md) vLLM, then start the server with the [`vllm serve`](../configuration/serve_args.md) command. (You can also use our [Docker](../deployment/docker.md) image.)

```bash
vllm serve NousResearch/Meta-Llama-3-8B-Instruct \
  --dtype auto \
  --api-key token-abc123
```

To call the server, in your preferred text editor, create a script that uses an HTTP client. Include any messages that you want to send to the model. Then run that script. Below is an example script using the [official OpenAI Python client](https://github.com/openai/openai-python).

??? code

    ```python
    from openai import OpenAI
    client = OpenAI(
        base_url="http://localhost:8000/v1",
        api_key="token-abc123",
    )

    completion = client.chat.completions.create(
        model="NousResearch/Meta-Llama-3-8B-Instruct",
        messages=[
            {"role": "user", "content": "Hello!"}
        ]
    )

    print(completion.choices[0].message)
    ```

!!! tip
    vLLM supports some parameters that are not supported by OpenAI, `top_k` for example.
    You can pass these parameters to vLLM using the OpenAI client in the `extra_body` parameter of your requests, i.e. `extra_body={"top_k": 50}` for `top_k`.

!!! important
    By default, the server applies `generation_config.json` from the Hugging Face model repository if it exists. This means the default values of certain sampling parameters can be overridden by those recommended by the model creator.

    To disable this behavior, please pass `--generation-config vllm` when launching the server.

## Supported APIs

We currently support the following OpenAI APIs:

- [Completions API][completions-api] (`/v1/completions`)
    - Only applicable to [text generation models](../models/generative_models.md).
    - *Note: `suffix` parameter is not supported.*
- [Chat Completions API][chat-api] (`/v1/chat/completions`)
    - Only applicable to [text generation models](../models/generative_models.md) with a [chat template][chat-template].
    - *Note: `parallel_tool_calls` and `user` parameters are ignored.*
- [Embeddings API][embeddings-api] (`/v1/embeddings`)
    - Only applicable to [embedding models](../models/pooling_models.md).
- [Transcriptions API][transcriptions-api] (`/v1/audio/transcriptions`)
    - Only applicable to [Automatic Speech Recognition (ASR) models](../models/supported_models.md#transcription).
- [Translation API][translations-api] (`/v1/audio/translations`)
    - Only applicable to [Automatic Speech Recognition (ASR) models](../models/supported_models.md#transcription).

In addition, we have the following custom APIs:

- [Tokenizer API][tokenizer-api] (`/tokenize`, `/detokenize`)
    - Applicable to any model with a tokenizer.
- [Pooling API][pooling-api] (`/pooling`)
    - Applicable to all [pooling models](../models/pooling_models.md).
- [Classification API][classification-api] (`/classify`)
    - Only applicable to [classification models](../models/pooling_models.md).
- [Score API][score-api] (`/score`)
    - Applicable to [embedding models and cross-encoder models](../models/pooling_models.md).
- [Re-rank API][rerank-api] (`/rerank`, `/v1/rerank`, `/v2/rerank`)
    - Implements [Jina AI's v1 re-rank API](https://jina.ai/reranker/)
    - Also compatible with [Cohere's v1 & v2 re-rank APIs](https://docs.cohere.com/v2/reference/rerank)
    - Jina and Cohere's APIs are very similar; Jina's includes extra information in the rerank endpoint's response.
    - Only applicable to [cross-encoder models](../models/pooling_models.md).

[](){ #chat-template }

## Chat Template

In order for the language model to support chat protocol, vLLM requires the model to include
a chat template in its tokenizer configuration. The chat template is a Jinja2 template that
specifies how are roles, messages, and other chat-specific tokens are encoded in the input.

An example chat template for `NousResearch/Meta-Llama-3-8B-Instruct` can be found [here](https://github.com/meta-llama/llama3?tab=readme-ov-file#instruction-tuned-models)

Some models do not provide a chat template even though they are instruction/chat fine-tuned. For those model,
you can manually specify their chat template in the `--chat-template` parameter with the file path to the chat
template, or the template in string form. Without a chat template, the server will not be able to process chat
and all chat requests will error.

```bash
vllm serve <model> --chat-template ./path-to-chat-template.jinja
```

vLLM community provides a set of chat templates for popular models. You can find them under the <gh-dir:examples> directory.

With the inclusion of multi-modal chat APIs, the OpenAI spec now accepts chat messages in a new format which specifies
both a `type` and a `text` field. An example is provided below:

```python
completion = client.chat.completions.create(
    model="NousResearch/Meta-Llama-3-8B-Instruct",
    messages=[
        {"role": "user", "content": [{"type": "text", "text": "Classify this sentiment: vLLM is wonderful!"}]}
    ]
)
```

Most chat templates for LLMs expect the `content` field to be a string, but there are some newer models like
`meta-llama/Llama-Guard-3-1B` that expect the content to be formatted according to the OpenAI schema in the
request. vLLM provides best-effort support to detect this automatically, which is logged as a string like
*"Detected the chat template content format to be..."*, and internally converts incoming requests to match
the detected format, which can be one of:

- `"string"`: A string.
    - Example: `"Hello world"`
- `"openai"`: A list of dictionaries, similar to OpenAI schema.
    - Example: `[{"type": "text", "text": "Hello world!"}]`

If the result is not what you expect, you can set the `--chat-template-content-format` CLI argument
to override which format to use.

## Extra Parameters

vLLM supports a set of parameters that are not part of the OpenAI API.
In order to use them, you can pass them as extra parameters in the OpenAI client.
Or directly merge them into the JSON payload if you are using HTTP call directly.

```python
completion = client.chat.completions.create(
    model="NousResearch/Meta-Llama-3-8B-Instruct",
    messages=[
        {"role": "user", "content": "Classify this sentiment: vLLM is wonderful!"}
    ],
    extra_body={
        "guided_choice": ["positive", "negative"]
    }
)
```

## Extra HTTP Headers

Only `X-Request-Id` HTTP request header is supported for now. It can be enabled
with `--enable-request-id-headers`.

??? code

    ```python
    completion = client.chat.completions.create(
        model="NousResearch/Meta-Llama-3-8B-Instruct",
        messages=[
            {"role": "user", "content": "Classify this sentiment: vLLM is wonderful!"}
        ],
        extra_headers={
            "x-request-id": "sentiment-classification-00001",
        }
    )
    print(completion._request_id)

    completion = client.completions.create(
        model="NousResearch/Meta-Llama-3-8B-Instruct",
        prompt="A robot may not injure a human being",
        extra_headers={
            "x-request-id": "completion-test",
        }
    )
    print(completion._request_id)
    ```

## API Reference

[](){ #completions-api }

### Completions API

Our Completions API is compatible with [OpenAI's Completions API](https://platform.openai.com/docs/api-reference/completions);
you can use the [official OpenAI Python client](https://github.com/openai/openai-python) to interact with it.

Code example: <gh-file:examples/online_serving/openai_completion_client.py>

#### Extra parameters

The following [sampling parameters][sampling-params] are supported.

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/protocol.py:completion-sampling-params"
    ```

The following extra parameters are supported:

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/protocol.py:completion-extra-params"
    ```

[](){ #chat-api }

### Chat API

Our Chat API is compatible with [OpenAI's Chat Completions API](https://platform.openai.com/docs/api-reference/chat);
you can use the [official OpenAI Python client](https://github.com/openai/openai-python) to interact with it.

We support both [Vision](https://platform.openai.com/docs/guides/vision)- and
[Audio](https://platform.openai.com/docs/guides/audio?audio-generation-quickstart-example=audio-in)-related parameters;
see our [Multimodal Inputs](../features/multimodal_inputs.md) guide for more information.

- *Note: `image_url.detail` parameter is not supported.*

Code example: <gh-file:examples/online_serving/openai_chat_completion_client.py>

#### Extra parameters

The following [sampling parameters][sampling-params] are supported.

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/protocol.py:chat-completion-sampling-params"
    ```

The following extra parameters are supported:

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/protocol.py:chat-completion-extra-params"
    ```

[](){ #embeddings-api }

### Embeddings API

Our Embeddings API is compatible with [OpenAI's Embeddings API](https://platform.openai.com/docs/api-reference/embeddings);
you can use the [official OpenAI Python client](https://github.com/openai/openai-python) to interact with it.

If the model has a [chat template][chat-template], you can replace `inputs` with a list of `messages` (same schema as [Chat API][chat-api])
which will be treated as a single prompt to the model.

Code example: <gh-file:examples/online_serving/openai_embedding_client.py>

#### Multi-modal inputs

You can pass multi-modal inputs to embedding models by defining a custom chat template for the server
and passing a list of `messages` in the request. Refer to the examples below for illustration.

=== "VLM2Vec"

    To serve the model:

    ```bash
    vllm serve TIGER-Lab/VLM2Vec-Full --runner pooling \
      --trust-remote-code \
      --max-model-len 4096 \
      --chat-template examples/template_vlm2vec.jinja
    ```

    !!! important
        Since VLM2Vec has the same model architecture as Phi-3.5-Vision, we have to explicitly pass `--runner pooling`
        to run this model in embedding mode instead of text generation mode.

        The custom chat template is completely different from the original one for this model,
        and can be found here: <gh-file:examples/template_vlm2vec.jinja>

    Since the request schema is not defined by OpenAI client, we post a request to the server using the lower-level `requests` library:

    ??? code

        ```python
        import requests

        image_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg"

        response = requests.post(
            "http://localhost:8000/v1/embeddings",
            json={
                "model": "TIGER-Lab/VLM2Vec-Full",
                "messages": [{
                    "role": "user",
                    "content": [
                        {"type": "image_url", "image_url": {"url": image_url}},
                        {"type": "text", "text": "Represent the given image."},
                    ],
                }],
                "encoding_format": "float",
            },
        )
        response.raise_for_status()
        response_json = response.json()
        print("Embedding output:", response_json["data"][0]["embedding"])
        ```

=== "DSE-Qwen2-MRL"

    To serve the model:

    ```bash
    vllm serve MrLight/dse-qwen2-2b-mrl-v1 --runner pooling \
      --trust-remote-code \
      --max-model-len 8192 \
      --chat-template examples/template_dse_qwen2_vl.jinja
    ```

    !!! important
        Like with VLM2Vec, we have to explicitly pass `--runner pooling`.

        Additionally, `MrLight/dse-qwen2-2b-mrl-v1` requires an EOS token for embeddings, which is handled
        by a custom chat template: <gh-file:examples/template_dse_qwen2_vl.jinja>

    !!! important
        `MrLight/dse-qwen2-2b-mrl-v1` requires a placeholder image of the minimum image size for text query embeddings. See the full code
        example below for details.

Full example: <gh-file:examples/online_serving/openai_chat_embedding_client_for_multimodal.py>

#### Extra parameters

The following [pooling parameters][pooling-params] are supported.

```python
--8<-- "vllm/entrypoints/openai/protocol.py:embedding-pooling-params"
```

The following extra parameters are supported by default:

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/protocol.py:embedding-extra-params"
    ```

For chat-like input (i.e. if `messages` is passed), these extra parameters are supported instead:

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/protocol.py:chat-embedding-extra-params"
    ```

[](){ #transcriptions-api }

### Transcriptions API

Our Transcriptions API is compatible with [OpenAI's Transcriptions API](https://platform.openai.com/docs/api-reference/audio/createTranscription);
you can use the [official OpenAI Python client](https://github.com/openai/openai-python) to interact with it.

!!! note
    To use the Transcriptions API, please install with extra audio dependencies using `pip install vllm[audio]`.

Code example: <gh-file:examples/online_serving/openai_transcription_client.py>
<!-- TODO: api enforced limits + uploading audios -->

#### API Enforced Limits

Set the maximum audio file size (in MB) that VLLM will accept, via the
`VLLM_MAX_AUDIO_CLIP_FILESIZE_MB` environment variable. Default is 25 MB.

#### Extra Parameters

The following [sampling parameters][sampling-params] are supported.

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/protocol.py:transcription-sampling-params"
    ```

The following extra parameters are supported:

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/protocol.py:transcription-extra-params"
    ```
  
[](){ #translations-api }

### Translations API

Our Translation API is compatible with [OpenAI's Translations API](https://platform.openai.com/docs/api-reference/audio/createTranslation);
you can use the [official OpenAI Python client](https://github.com/openai/openai-python) to interact with it.
Whisper models can translate audio from one of the 55 non-English supported languages into English.
Please mind that the popular `openai/whisper-large-v3-turbo` model does not support translating.

!!! note
    To use the Translation API, please install with extra audio dependencies using `pip install vllm[audio]`.

Code example: <gh-file:examples/online_serving/openai_translation_client.py>

#### Extra Parameters

The following [sampling parameters][sampling-params] are supported.

```python
--8<-- "vllm/entrypoints/openai/protocol.py:translation-sampling-params"
```

The following extra parameters are supported:

```python
--8<-- "vllm/entrypoints/openai/protocol.py:translation-extra-params"
```

[](){ #tokenizer-api }

### Tokenizer API

Our Tokenizer API is a simple wrapper over [HuggingFace-style tokenizers](https://huggingface.co/docs/transformers/en/main_classes/tokenizer).
It consists of two endpoints:

- `/tokenize` corresponds to calling `tokenizer.encode()`.
- `/detokenize` corresponds to calling `tokenizer.decode()`.

[](){ #pooling-api }

### Pooling API

Our Pooling API encodes input prompts using a [pooling model](../models/pooling_models.md) and returns the corresponding hidden states.

The input format is the same as [Embeddings API][embeddings-api], but the output data can contain an arbitrary nested list, not just a 1-D list of floats.

Code example: <gh-file:examples/online_serving/openai_pooling_client.py>

[](){ #classification-api }

### Classification API

Our Classification API directly supports Hugging Face sequence-classification models such as [ai21labs/Jamba-tiny-reward-dev](https://huggingface.co/ai21labs/Jamba-tiny-reward-dev) and [jason9693/Qwen2.5-1.5B-apeach](https://huggingface.co/jason9693/Qwen2.5-1.5B-apeach).

We automatically wrap any other transformer via `as_seq_cls_model()`, which pools on the last token, attaches a `RowParallelLinear` head, and applies a softmax to produce per-class probabilities.

Code example: <gh-file:examples/online_serving/openai_classification_client.py>

#### Example Requests

You can classify multiple texts by passing an array of strings:

```bash
curl -v "http://127.0.0.1:8000/classify" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "jason9693/Qwen2.5-1.5B-apeach",
    "input": [
      "Loved the new café—coffee was great.",
      "This update broke everything. Frustrating."
    ]
  }'
```

??? console "Response"

    ```json
    {
      "id": "classify-7c87cac407b749a6935d8c7ce2a8fba2",
      "object": "list",
      "created": 1745383065,
      "model": "jason9693/Qwen2.5-1.5B-apeach",
      "data": [
        {
          "index": 0,
          "label": "Default",
          "probs": [
            0.565970778465271,
            0.4340292513370514
          ],
          "num_classes": 2
        },
        {
          "index": 1,
          "label": "Spoiled",
          "probs": [
            0.26448777318000793,
            0.7355121970176697
          ],
          "num_classes": 2
        }
      ],
      "usage": {
        "prompt_tokens": 20,
        "total_tokens": 20,
        "completion_tokens": 0,
        "prompt_tokens_details": null
      }
    }
    ```

You can also pass a string directly to the `input` field:

```bash
curl -v "http://127.0.0.1:8000/classify" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "jason9693/Qwen2.5-1.5B-apeach",
    "input": "Loved the new café—coffee was great."
  }'
```

??? console "Response"

    ```json
    {
      "id": "classify-9bf17f2847b046c7b2d5495f4b4f9682",
      "object": "list",
      "created": 1745383213,
      "model": "jason9693/Qwen2.5-1.5B-apeach",
      "data": [
        {
          "index": 0,
          "label": "Default",
          "probs": [
            0.565970778465271,
            0.4340292513370514
          ],
          "num_classes": 2
        }
      ],
      "usage": {
        "prompt_tokens": 10,
        "total_tokens": 10,
        "completion_tokens": 0,
        "prompt_tokens_details": null
      }
    }
    ```

#### Extra parameters

The following [pooling parameters][pooling-params] are supported.

```python
--8<-- "vllm/entrypoints/openai/protocol.py:classification-pooling-params"
```

The following extra parameters are supported:

```python
--8<-- "vllm/entrypoints/openai/protocol.py:classification-extra-params"
```

[](){ #score-api }

### Score API

Our Score API can apply a cross-encoder model or an embedding model to predict scores for sentence or multimodal pairs. When using an embedding model the score corresponds to the cosine similarity between each embedding pair.
Usually, the score for a sentence pair refers to the similarity between two sentences, on a scale of 0 to 1.

You can find the documentation for cross encoder models at [sbert.net](https://www.sbert.net/docs/package_reference/cross_encoder/cross_encoder.html).

Code example: <gh-file:examples/online_serving/openai_cross_encoder_score.py>

#### Single inference

You can pass a string to both `text_1` and `text_2`, forming a single sentence pair.

```bash
curl -X 'POST' \
  'http://127.0.0.1:8000/score' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "model": "BAAI/bge-reranker-v2-m3",
  "encoding_format": "float",
  "text_1": "What is the capital of France?",
  "text_2": "The capital of France is Paris."
}'
```

??? console "Response"

    ```json
    {
      "id": "score-request-id",
      "object": "list",
      "created": 693447,
      "model": "BAAI/bge-reranker-v2-m3",
      "data": [
        {
          "index": 0,
          "object": "score",
          "score": 1
        }
      ],
      "usage": {}
    }
    ```

#### Batch inference

You can pass a string to `text_1` and a list to `text_2`, forming multiple sentence pairs
where each pair is built from `text_1` and a string in `text_2`.
The total number of pairs is `len(text_2)`.

??? console "Request"

    ```bash
    curl -X 'POST' \
      'http://127.0.0.1:8000/score' \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{
      "model": "BAAI/bge-reranker-v2-m3",
      "text_1": "What is the capital of France?",
      "text_2": [
        "The capital of Brazil is Brasilia.",
        "The capital of France is Paris."
      ]
    }'
    ```

??? console "Response"

    ```json
    {
      "id": "score-request-id",
      "object": "list",
      "created": 693570,
      "model": "BAAI/bge-reranker-v2-m3",
      "data": [
        {
          "index": 0,
          "object": "score",
          "score": 0.001094818115234375
        },
        {
          "index": 1,
          "object": "score",
          "score": 1
        }
      ],
      "usage": {}
    }
    ```

You can pass a list to both `text_1` and `text_2`, forming multiple sentence pairs
where each pair is built from a string in `text_1` and the corresponding string in `text_2` (similar to `zip()`).
The total number of pairs is `len(text_2)`.

??? console "Request"

    ```bash
    curl -X 'POST' \
      'http://127.0.0.1:8000/score' \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{
      "model": "BAAI/bge-reranker-v2-m3",
      "encoding_format": "float",
      "text_1": [
        "What is the capital of Brazil?",
        "What is the capital of France?"
      ],
      "text_2": [
        "The capital of Brazil is Brasilia.",
        "The capital of France is Paris."
      ]
    }'
    ```

??? console "Response"

    ```json
    {
      "id": "score-request-id",
      "object": "list",
      "created": 693447,
      "model": "BAAI/bge-reranker-v2-m3",
      "data": [
        {
          "index": 0,
          "object": "score",
          "score": 1
        },
        {
          "index": 1,
          "object": "score",
          "score": 1
        }
      ],
      "usage": {}
    }
    ```

#### Multi-modal inputs

You can pass multi-modal inputs to scoring models by passing `content` including a list of multi-modal input (image, etc.) in the request. Refer to the examples below for illustration.

=== "JinaVL-Reranker"

    To serve the model:

    ```bash
    vllm serve jinaai/jina-reranker-m0
    ```

    Since the request schema is not defined by OpenAI client, we post a request to the server using the lower-level `requests` library:

    ??? Code

        ```python
        import requests

        response = requests.post(
            "http://localhost:8000/v1/score",
            json={
                "model": "jinaai/jina-reranker-m0",
                "text_1": "slm markdown",
                "text_2": {
                  "content": [
                          {
                              "type": "image_url",
                              "image_url": {
                                  "url": "https://raw.githubusercontent.com/jina-ai/multimodal-reranker-test/main/handelsblatt-preview.png"
                              },
                          },
                          {
                              "type": "image_url",
                              "image_url": {
                                  "url": "https://raw.githubusercontent.com/jina-ai/multimodal-reranker-test/main/paper-11.png"
                              },
                          },
                      ]
                  }
                },
        )
        response.raise_for_status()
        response_json = response.json()
        print("Scoring output:", response_json["data"][0]["score"])
        print("Scoring output:", response_json["data"][1]["score"])
        ```
Full example: <gh-file:examples/online_serving/openai_cross_encoder_score_for_multimodal.py>

#### Extra parameters

The following [pooling parameters][pooling-params] are supported.

```python
--8<-- "vllm/entrypoints/openai/protocol.py:score-pooling-params"
```

The following extra parameters are supported:

```python
--8<-- "vllm/entrypoints/openai/protocol.py:score-extra-params"
```

[](){ #rerank-api }

### Re-rank API

Our Re-rank API can apply an embedding model or a cross-encoder model to predict relevant scores between a single query, and
each of a list of documents. Usually, the score for a sentence pair refers to the similarity between two sentences or multi-modal inputs (image, etc.), on a scale of 0 to 1.

You can find the documentation for cross encoder models at [sbert.net](https://www.sbert.net/docs/package_reference/cross_encoder/cross_encoder.html).

The rerank endpoints support popular re-rank models such as `BAAI/bge-reranker-base` and other models supporting the
`score` task. Additionally, `/rerank`, `/v1/rerank`, and `/v2/rerank`
endpoints are compatible with both [Jina AI's re-rank API interface](https://jina.ai/reranker/) and
[Cohere's re-rank API interface](https://docs.cohere.com/v2/reference/rerank) to ensure compatibility with
popular open-source tools.

Code example: <gh-file:examples/online_serving/jinaai_rerank_client.py>

#### Example Request

Note that the `top_n` request parameter is optional and will default to the length of the `documents` field.
Result documents will be sorted by relevance, and the `index` property can be used to determine original order.

??? console "Request"

    ```bash
    curl -X 'POST' \
      'http://127.0.0.1:8000/v1/rerank' \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{
      "model": "BAAI/bge-reranker-base",
      "query": "What is the capital of France?",
      "documents": [
        "The capital of Brazil is Brasilia.",
        "The capital of France is Paris.",
        "Horses and cows are both animals"
      ]
    }'
    ```

??? console "Response"

    ```json
    {
      "id": "rerank-fae51b2b664d4ed38f5969b612edff77",
      "model": "BAAI/bge-reranker-base",
      "usage": {
        "total_tokens": 56
      },
      "results": [
        {
          "index": 1,
          "document": {
            "text": "The capital of France is Paris."
          },
          "relevance_score": 0.99853515625
        },
        {
          "index": 0,
          "document": {
            "text": "The capital of Brazil is Brasilia."
          },
          "relevance_score": 0.0005860328674316406
        }
      ]
    }
    ```

#### Extra parameters

The following [pooling parameters][pooling-params] are supported.

```python
--8<-- "vllm/entrypoints/openai/protocol.py:rerank-pooling-params"
```

The following extra parameters are supported:

```python
--8<-- "vllm/entrypoints/openai/protocol.py:rerank-extra-params"
```

## Ray Serve LLM

Ray Serve LLM enables scalable, production-grade serving of the vLLM engine. It integrates tightly with vLLM and extends it with features such as auto-scaling, load balancing, and back-pressure.

Key capabilities:

- Exposes an OpenAI-compatible HTTP API as well as a Pythonic API.
- Scales from a single GPU to a multi-node cluster without code changes.
- Provides observability and autoscaling policies through Ray dashboards and metrics.

The following example shows how to deploy a large model like DeepSeek R1 with Ray Serve LLM: <gh-file:examples/online_serving/ray_serve_deepseek.py>.

Learn more about Ray Serve LLM with the official [Ray Serve LLM documentation](https://docs.ray.io/en/latest/serve/llm/serving-llms.html).
