export async function streamChat(message: string, sessionId?: string, signal?: AbortSignal) {
  if (!sessionId) {
    throw new Error("Session ID is required")
  }

  // 使用后端的流式聊天接口
  const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8080/api"
  
  // 确保参数与后端ChatStreamGet方法匹配
  const url = `${API_BASE_URL}/conversation/chat/stream?message=${encodeURIComponent(message)}&sessionId=${sessionId}`

  // 发送请求
  try {
    console.log("发送流式聊天请求:", url) // 添加日志以便调试
    const response = await fetch(url, {
      method: "GET",
      headers: {
        Accept: "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
      },
      // 使用传入的signal用于取消请求
      signal,
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => null)
      throw new Error(errorData?.error || `API request failed with status ${response.status}`)
    }

    return response
  } catch (error) {
    console.error("Stream chat error:", error)
    throw error
  }
}

