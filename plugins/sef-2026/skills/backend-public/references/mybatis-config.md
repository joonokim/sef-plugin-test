# MyBatis Configuration Reference

## Data Access Pattern

```
Service → Mapper (interface) → MyBatis XML → Database
```

No Repository layer. No Vo objects. Domain entities are passed directly to Mapper methods.

## Directory Structure

```
src/main/
├── java/com/sqisoft/sef/modules/{module}/
│   ├── domain/{Entity}.java         # Domain entity (passed to Mapper)
│   └── mapper/{Entity}Mapper.java   # @Mapper("nameMapper") interface
└── resources/mybatis/
    ├── config/mybatis-config.xml
    └── mapper/{module}/{Entity}Mapper.xml
```

## mybatis-config.xml (Actual)

```xml
<configuration>
    <settings>
        <setting name="callSettersOnNulls" value="true"/>
        <setting name="jdbcTypeForNull" value="NULL"/>
        <setting name="cacheEnabled" value="false"/>
        <setting name="useGeneratedKeys" value="false"/>
        <setting name="mapUnderscoreToCamelCase" value="true"/>
        <setting name="autoMappingUnknownColumnBehavior" value="NONE"/>
    </settings>
    <typeHandlers>
        <typeHandler handler="org.apache.ibatis.type.LocalDateTimeTypeHandler"
                     javaType="java.time.LocalDateTime" jdbcType="DATE"/>
        <typeHandler handler="org.apache.ibatis.type.LocalDateTimeTypeHandler"
                     javaType="java.time.LocalDateTime" jdbcType="TIMESTAMP"/>
    </typeHandlers>
</configuration>
```

Key: `cacheEnabled=false`, `mapUnderscoreToCamelCase=true` (DB `user_name` → Java `userName` automatically).

## application.yml

```yaml
mybatis:
  config-location: classpath:mybatis/config/mybatis-config.xml
  mapper-locations: classpath*:mybatis/mapper/**/*.xml
```

## Mapper Interface

Uses eGovFrame `@Mapper` annotation with bean name (NOT `org.apache.ibatis.annotations.Mapper`):

```java
import org.egovframe.rte.psl.dataaccess.mapper.Mapper;

@Mapper("boardMapper")
public interface BoardMapper {
    List<Board> findAllByMenuIdWithPaging(@Param("menuId") String menuId, @Param("request") BoardSearchRequest request);
    int countByMenuIdAndSearchCondition(@Param("menuId") String menuId, @Param("request") BoardSearchRequest request);
    Optional<Board> findByMenuIdAndBbsSq(@Param("menuId") String menuId, @Param("bbsSq") Long bbsSq);
    long save(Board board);
    int update(Board board);
}
```

No `@MapperScan` annotation is used. Mapper registration is handled by eGovFrame's `MapperConfigurer` in `MapperConfig.java` with base package `com.sqisoft.sef.modules`.

## XML Mapper

```xml
<mapper namespace="com.sqisoft.sef.modules.board.mapper.BoardMapper">

    <select id="findByMenuIdAndBbsSq" resultType="com.sqisoft.sef.modules.board.domain.Board">
        SELECT bbs_sq, menu_id, bbs_ttl, bbs_cn, inq_cnt, del_yn, rgtr_id AS rgtrId, reg_dt AS regDt, mdfr_id AS mdfrId, mdfr_dt AS mdfrDt
        FROM tb_board
        WHERE menu_id = #{menuId} AND bbs_sq = #{bbsSq} AND del_yn = 'N'
    </select>

    <insert id="save" useGeneratedKeys="true" keyProperty="bbsSq" keyColumn="bbs_sq">
        INSERT INTO tb_board (menu_id, bbs_ttl, bbs_cn, del_yn, rgtr_id, reg_dt, mdfr_id, mdfr_dt)
        VALUES (#{menuId}, #{bbsTtl}, #{bbsCn}, 'N', #{rgtrId}, NOW(), #{mdfrId}, NOW())
    </insert>

    <update id="update">
        UPDATE tb_board SET bbs_ttl = #{bbsTtl}, bbs_cn = #{bbsCn}, mdfr_id = #{mdfrId}, mdfr_dt = NOW()
        WHERE bbs_sq = #{bbsSq}
    </update>
</mapper>
```

Column mapping is automatic via `mapUnderscoreToCamelCase=true`. Use `resultType` pointing to domain entity directly.

## Oracle vs PostgreSQL

| Feature | PostgreSQL | Oracle |
|---------|-----------|--------|
| Timestamp | `NOW()` | `SYSDATE` |
| Paging | `LIMIT #{limit} OFFSET #{offset}` | `ROW_NUMBER() OVER` subquery |
| Auto ID | `SERIAL` / `useGeneratedKeys` | `SEQUENCE` + `<selectKey>` |
| String concat | `\|\|` | `\|\|` |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Mapper not found | Check `@Mapper("beanName")` uses eGovFrame import, verify MapperConfig base package |
| Column mapping fails | Verify `mapUnderscoreToCamelCase=true` in mybatis-config.xml |
| Transaction not working | Ensure `@Transactional` on public methods in ServiceImpl |
| Null params error | `jdbcTypeForNull=NULL` setting handles this |
