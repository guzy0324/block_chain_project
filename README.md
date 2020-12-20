# Block Chain Project

[TOC]

## Requirements

- 功能一：实现采购商品—签发应收账款 交易上链。例如车企从轮胎公司购买一批轮胎并签订应收账款单据。
- 功能二：实现应收账款的转让上链，轮胎公司从轮毂公司购买一笔轮毂，便将于车企的应收账款单据部分转让给轮毂公司。轮毂公司可以利用这个新的单据去融资或者要求车企到期时归还钱款。
- 功能三：利用应收账款向银行融资上链，供应链上所有可以利用应收账款单据向银行申请融资。
- 功能四：应收账款支付结算上链，应收账款单据到期时核心企业向下游企业支付相应的欠款。

Be detailed in [2020.docx](https://github.com/guzy0324/block_chain_project/releases/download/v0.0.0/2020.docx).

## 初版实现方案

- Database:
    |主码  |债权人      |债务人      |还款日期      |挂起     |金额   |
    |------|-----------|-----------|-------------|---------|-------|
    |id    |creditor   |debtor     |ddl          |pending  |value  |
    |string|address    |address    |uint256      |address  |uint256|

    注意！：这个id是因为这个奇怪的数据库需要主码，但实际上无用，所以均设为一个全局变量（这个主码竟然是可以重复的
- 功能一：债权人发起，（债权人，债务人，还款日期）如有则直接修改value，否则插入一条新记录
- 功能二：债权人发起，减少记录金额，插入一条新记录金额为减少的金额（“插入”同样按照功能一的方式先做判断，看是修改还是插入）
- 功能三：债权人发起，向银行账户申请转移债券，设置pending为银行账户；银行可以取消pending（设为0）将债权人改为自己（“改”同样按照功能一的方式先做判断，看是修改哪个）。
- 功能四：债权人发起，（判断时间）删除一条记录

## 最终实现

- [数据库](#数据库)
- [返回码](#返回码)
- [函数](#函数)
    - [register](#register)
    - [select](#select)
    - [insert_core](#insert_core)
    - [insert](#insert)
    - [is_bank](#is_bank)
    - [mortgage](#mortgage)
    - [permit](#permit)
    - [assign](#assign)

1. <span id="数据库">数据库</span>
    - debt表
        |所有者(主码)|债权人  |债务人 |还款日期|金额 |
        |------------|--------|-------|--------|-----|
        |owner       |creditor|debtor |ddl     |value|
        |string      |string  |string |int     |int  |
        其中保证(owner,creditor,debtor,ddl)唯一确定一条记录。

        将owner和creditor不一致的欠条定义为挂起态，将一致的欠条定义为正常态。
    - account表
        |用户名(主码)|公司类型|
        |------------|--------|
        |id          |type    |
        |address     |int     |
        其中保证(id)唯一确定一条记录。
2. <span id="返回码">返回码</span>
    - MORTGAGE_TO_DEBTOR：以欠条向银行抵押，其中欠条的债务人就是这个银行，从而引发错误。
    - NOT_BANK：当某操作对象必须是银行，但不是银行，引发错误。
    - REGISTERED：该地址已注册账户，引发错误。
    - ID_EXIST：注册时该用户名已存在，引发错误。
    - OVERFLOW：转移欠条时，指定金额超出欠条金额，引发错误。
    - NOT_EXIST：该欠条不存在，引发错误。
    - DB_ERR：数据库操作出错。
    - SUCC：成功。
3. <span id="函数">函数</span>
    - <span id="register">register</span>
        - 描述：公司账户注册
        - 公有：是
        - 参数：
            - id：公司账户名
            - type：公司类型
        - 返回值：
            - [返回码](#返回码)
    - <span id="select">select</span>
        - 描述：查询所有者为自己的全部debt
        - 公有：是
        - 参数：无
        - 返回值：
            - DEBT数组
    - <span id="insert_core">insert_core</span>
        - 描述：添加一个欠条，如果存在相关欠条更新其value，否则插入一条新的欠条
        - 公有：否
        - 参数：
            - id：欠条的onwner
            - creditor：欠条的creditor
            - debtor：欠条的debtor
            - ddl：欠条的ddl
            - value：欠条的value
        - 返回值：
            - [返回码](#返回码)
    - <span id="insert">insert</span>
        - 描述：添加一个欠条，其中owner和creditor均为自己
        - 公有：是
        - 参数：
            - debtor：欠条的debtor
            - ddl：欠条的ddl
            - value：欠条的value
        - 返回值：
            - [返回码](#返回码)
    - <span id="is_bank">is_bank</span>
        - 描述：判断该公司账户是不是银行
        - 公有：否
        - 参数：
            - bank：判断的银行账户名
        - 返回值：
            - [返回码](#返回码)
    - <span id="mortgage">mortgage</span>
        - 描述：用部分或全部[正常态](#数据库)的欠条向银行申请抵押，将owner设为银行，creditor仍设为自己，欠条由[正常态](#数据库)转变为[挂起态](#数据库)。
        - 公有：是
        - 参数：
            - bank：银行账户名
            - debtor：欠条的debtor
            - ddl：欠条的ddl
            - value：需要抵押的value
        - 返回值：
            - [返回码](#返回码)
    - <span id="permit">permit</span>
        - 描述：银行处理指定抵押申请，若同意将creditor设为银行，若拒绝将owner设为申请者，欠条由[挂起态](#数据库)转变为[正常态](#数据库)。
        - 公有：是
        - 参数：
            - boolean：0为拒绝，非0为同意
            - creditor：欠条的creaditor
            - debtor：欠条的debtor
            - ddl：欠条的ddl
        - 返回值：
            - [返回码](#返回码)
    - <span id="assign">assign</span>
        - 描述：转移部分或全部[正常态](#数据库)的欠条给别人，如果目标是欠条的debtor视为还款，如果目标不是欠条的debtor视为交易欠条
        - 公有：是
        - 参数：
            - creditor：转移目标
            - debtor：欠条的debtor
            - ddl：欠条的ddl
            - value：需要转移的value
        - 返回值
            - [返回码](#返回码)

## 分工

- [x] 实现方案：谷正阳，陈振宇
- [x] Database：谷正阳
- [x] 功能一：陈嘉宁
- [x] 功能二：陈振宇
- [x] 功能三：陈嘉宁
- [x] 功能四：陈振宇
- [x] Debug及代码修改：谷正阳
- [x] 文档：谷正阳
- [ ] 测试
