package org.xhy.domain.agent.repository;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.xhy.domain.agent.model.AgentEmbedEntity;
import org.xhy.infrastructure.repository.MyBatisPlusExtRepository;

import java.util.List;

/** Agent嵌入配置仓储接口 */
@Mapper
public interface AgentEmbedRepository extends MyBatisPlusExtRepository<AgentEmbedEntity> {


}