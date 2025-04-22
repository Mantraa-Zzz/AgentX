package org.xhy.interfaces.dto.agent.request;

/**
 * 更新Agent基本信息的请求对象
 */
public class UpdateAgentBasicInfoRequest {
    
    private String name;
    private String avatar;
    private String description;
    
    // 构造方法
    public UpdateAgentBasicInfoRequest() {
    }
    
    public UpdateAgentBasicInfoRequest(String name, String avatar, String description) {
        this.name = name;
        this.avatar = avatar;
        this.description = description;
    }

    // Getter和Setter
    public String getName() {
        return name;
    }
    
    public void setName(String name) {
        this.name = name;
    }
    
    public String getAvatar() {
        return avatar;
    }
    
    public void setAvatar(String avatar) {
        this.avatar = avatar;
    }
    
    public String getDescription() {
        return description;
    }
    
    public void setDescription(String description) {
        this.description = description;
    }
} 