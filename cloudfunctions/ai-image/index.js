const https = require("https");

const DASHSCOPE_API_HOST = "dashscope.aliyuncs.com";
const CREATE_IMAGE_PATH = "/api/v1/services/aigc/text2image/image-synthesis";
const MODEL_NAME = "wanx2.1-t2i-plus";

exports.main = async function main(event) {
  const payload = typeof event === "string" ? JSON.parse(event) : event || {};
  const name = payload.name;

  if (name === "create") {
    return createImageTask(payload);
  }

  if (name === "result") {
    return getImageTaskResult(payload);
  }

  if (name === "regenerate") {
    return createImageTask({
      ...payload,
      seed: nextSeed(payload.seed),
    });
  }

  return {
    ok: false,
    code: "INVALID_NAME",
    message: "name 只支持 create、result、regenerate",
  };
};

async function createImageTask(payload) {
  const apiKey = process.env.DASHSCOPE_API_KEY;
  if (!apiKey) {
    return {
      ok: false,
      code: "MISSING_API_KEY",
      message: "请在云函数环境变量中配置 DASHSCOPE_API_KEY",
    };
  }

  const prompt = sanitizeText(payload.prompt, 800);
  if (!prompt) {
    return {
      ok: false,
      code: "EMPTY_PROMPT",
      message: "请输入文生图提示词",
    };
  }

  const negativePrompt = sanitizeText(
    payload.negative_prompt || payload.negativePrompt || defaultNegativePrompt(),
    500
  );
  const size = normalizeSize(payload.size);
  const n = clampInteger(payload.n, 1, 4, 1);
  const seed = normalizeSeed(payload.seed);
  const promptExtend = payload.prompt_extend ?? payload.promptExtend ?? true;
  const watermark = payload.watermark ?? false;

  const body = {
    model: MODEL_NAME,
    input: {
      prompt,
      negative_prompt: negativePrompt,
    },
    parameters: {
      size,
      n,
      prompt_extend: Boolean(promptExtend),
      watermark: Boolean(watermark),
    },
  };

  if (seed !== undefined) {
    body.parameters.seed = seed;
  }

  const response = await requestDashScope({
    method: "POST",
    path: CREATE_IMAGE_PATH,
    apiKey,
    asyncTask: true,
    body,
  });

  if (!response.ok) {
    return response;
  }

  return {
    ok: true,
    name: "create",
    model: MODEL_NAME,
    task_id: response.data.output && response.data.output.task_id,
    task_status: response.data.output && response.data.output.task_status,
    request_id: response.data.request_id,
    seed,
  };
}

async function getImageTaskResult(payload) {
  const apiKey = process.env.DASHSCOPE_API_KEY;
  if (!apiKey) {
    return {
      ok: false,
      code: "MISSING_API_KEY",
      message: "请在云函数环境变量中配置 DASHSCOPE_API_KEY",
    };
  }

  const taskID = sanitizeTaskID(payload.task_id || payload.taskId);
  if (!taskID) {
    return {
      ok: false,
      code: "EMPTY_TASK_ID",
      message: "请传入 task_id",
    };
  }

  const response = await requestDashScope({
    method: "GET",
    path: `/api/v1/tasks/${encodeURIComponent(taskID)}`,
    apiKey,
  });

  if (!response.ok) {
    return response;
  }

  const output = response.data.output || {};
  return {
    ok: true,
    name: "result",
    task_id: output.task_id,
    task_status: output.task_status,
    request_id: response.data.request_id,
    submit_time: output.submit_time,
    scheduled_time: output.scheduled_time,
    end_time: output.end_time,
    results: Array.isArray(output.results) ? output.results : [],
    task_metrics: output.task_metrics,
    usage: response.data.usage,
    code: response.data.code,
    message: response.data.message,
  };
}

function requestDashScope({ method, path, apiKey, asyncTask = false, body }) {
  return new Promise((resolve) => {
    const bodyText = body ? JSON.stringify(body) : undefined;
    const headers = {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    };

    if (asyncTask) {
      headers["X-DashScope-Async"] = "enable";
    }

    if (bodyText) {
      headers["Content-Length"] = Buffer.byteLength(bodyText);
    }

    const request = https.request(
      {
        hostname: DASHSCOPE_API_HOST,
        path,
        method,
        headers,
        timeout: 30000,
      },
      (response) => {
        let raw = "";
        response.setEncoding("utf8");
        response.on("data", (chunk) => {
          raw += chunk;
        });
        response.on("end", () => {
          let data = {};
          try {
            data = raw ? JSON.parse(raw) : {};
          } catch (error) {
            resolve({
              ok: false,
              code: "INVALID_JSON",
              message: `DashScope 返回了无法解析的响应：${raw.slice(0, 160)}`,
            });
            return;
          }

          if (response.statusCode >= 200 && response.statusCode < 300 && !data.code) {
            resolve({ ok: true, data });
            return;
          }

          resolve({
            ok: false,
            code: data.code || `HTTP_${response.statusCode}`,
            message: data.message || "DashScope 请求失败",
            request_id: data.request_id,
          });
        });
      }
    );

    request.on("timeout", () => {
      request.destroy(new Error("DashScope 请求超时"));
    });

    request.on("error", (error) => {
      resolve({
        ok: false,
        code: "REQUEST_FAILED",
        message: error.message,
      });
    });

    if (bodyText) {
      request.write(bodyText);
    }
    request.end();
  });
}

function sanitizeText(value, maxLength) {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim().slice(0, maxLength);
}

function sanitizeTaskID(value) {
  if (typeof value !== "string") {
    return "";
  }
  const taskID = value.trim();
  return /^[a-zA-Z0-9_-]{8,80}$/.test(taskID) ? taskID : "";
}

function normalizeSize(value) {
  if (typeof value !== "string") {
    return "1024*1024";
  }
  return /^\d{3,4}\*\d{3,4}$/.test(value) ? value : "1024*1024";
}

function normalizeSeed(value) {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }
  return clampInteger(value, 0, 2147483647, undefined);
}

function clampInteger(value, min, max, fallback) {
  const number = Number.parseInt(value, 10);
  if (!Number.isFinite(number)) {
    return fallback;
  }
  return Math.min(max, Math.max(min, number));
}

function nextSeed(value) {
  const seed = normalizeSeed(value);
  if (seed === undefined) {
    return Math.floor(Math.random() * 2147483647);
  }
  return (seed + 9973) % 2147483647;
}

function defaultNegativePrompt() {
  return "低质量、低分辨率、畸形、错误结构、多余手指、文字、水印、血腥、暴力、色情、未成年人、名人肖像";
}
