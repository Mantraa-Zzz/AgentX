package org.xhy.interfaces.dto.agent.request;

/**
 * 更新Agent状态的请求对象
 */
public class UpdateAgentStatusRequest {
    
    private Boolean enabled;
    
    // 构造方法
    public UpdateAgentStatusRequest() {
    }
    
    public UpdateAgentStatusRequest(Boolean enabled) {
        this.enabled = enabled;
    }
    
    // Getter和Setter
    public Boolean getEnabled() {
        return enabled;
    }
    
    public void setEnabled(Boolean enabled) {
        this.enabled = enabled;
    }
} 