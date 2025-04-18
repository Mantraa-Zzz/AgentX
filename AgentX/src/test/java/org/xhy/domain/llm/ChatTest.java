package org.xhy.domain.llm;

import dev.langchain4j.data.image.Image;
import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.mcp.McpToolProvider;
import dev.langchain4j.mcp.client.DefaultMcpClient;
import dev.langchain4j.mcp.client.McpClient;
import dev.langchain4j.mcp.client.transport.McpTransport;
import dev.langchain4j.mcp.client.transport.stdio.StdioMcpTransport;
import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.chat.response.ChatResponse;
import dev.langchain4j.model.chat.response.StreamingChatResponseHandler;
import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiImageModel;
import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
import dev.langchain4j.model.output.Response;
import dev.langchain4j.service.AiServices;
import dev.langchain4j.service.tool.ToolProvider;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.List;
import java.util.concurrent.CountDownLatch;

@SpringBootTest
public class ChatTest {

    interface Agent{
        AiMessage chat(String prompt);
    }
    public static void main(String[] args) {
        agent();
    }

    public static void agent(){
        OpenAiChatModel.OpenAiChatModelBuilder builder = OpenAiChatModel.builder();
        ChatLanguageModel model = builder.apiKey(System.getenv("SILICONFLOW_API_KEY"))
                .baseUrl("https://api.siliconflow.cn/v1")
                .modelName("Qwen/QwQ-32B").build();
        McpTransport transport = new StdioMcpTransport.Builder()
                .command(List.of("npx", "-y","@smithery/cli@latest","run","@yokingma/time-mcp","--key","def1f067-c5b7-443f-af21-2a80c5f176d9"))
                .logEvents(true) // only if you want to see the traffic in the log
                .build();
        McpClient mcpClient = new DefaultMcpClient.Builder()
                .transport(transport)
                .build();
        ToolProvider toolProvider = McpToolProvider.builder()
                .mcpClients(List.of(mcpClient))
                .build();
        Agent agent = AiServices.builder(Agent.class)
                .chatLanguageModel(model)
                .toolProvider(toolProvider)
                .build();
        AiMessage aiMessage = agent.chat("纽约时间和北京时间");
        System.out.println(aiMessage);
    }


    public static void chat(){
        OpenAiChatModel.OpenAiChatModelBuilder builder = OpenAiChatModel.builder();
        OpenAiChatModel build = builder.apiKey(System.getenv("SILICONFLOW_API_KEY"))
                .baseUrl("https://api.siliconflow.cn/v1")
                .modelName("Qwen/Qwen2.5-VL-72B-Instruct").build();
        String response = build.chat("你是谁");
        System.out.println(response);
    }

    public static void streamChat() {
        OpenAiStreamingChatModel.OpenAiStreamingChatModelBuilder builder = OpenAiStreamingChatModel.builder();
        OpenAiStreamingChatModel build = builder.apiKey(System.getenv("SILICONFLOW_API_KEY"))
                .baseUrl("https://api.siliconflow.cn/v1")
                .modelName("Qwen/Qwen2.5-VL-72B-Instruct").build();

        // 创建一个CountDownLatch用于等待流式输出完成
        CountDownLatch latch = new CountDownLatch(1);

        build.chat("你是谁", new StreamingChatResponseHandler() {
            @Override
            public void onPartialResponse(String partialResponse) {
                System.out.println(partialResponse);
            }

            @Override
            public void onCompleteResponse(ChatResponse completeResponse) {
                System.out.println("输出完了");
                // 流式输出完成，释放锁
                latch.countDown();
            }

            @Override
            public void onError(Throwable error) {
                System.out.println(error.getMessage());
                // 出错时也要释放锁，避免程序永远等待
                latch.countDown();
            }
        });

        try {
            // 主线程等待流式输出完成
            latch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            System.err.println("等待流式输出过程被中断: " + e.getMessage());
        }
    }
}
