# Block Chain Project

## Requirements:

- 功能一：实现采购商品—签发应收账款 交易上链。例如车企从轮胎公司购买一批轮胎并签订应收账款单据。
- 功能二：实现应收账款的转让上链，轮胎公司从轮毂公司购买一笔轮毂，便将于车企的应收账款单据部分转让给轮毂公司。轮毂公司可以利用这个新的单据去融资或者要求车企到期时归还钱款。
- 功能三：利用应收账款向银行融资上链，供应链上所有可以利用应收账款单据向银行申请融资。
- 功能四：应收账款支付结算上链，应收账款单据到期时核心企业向下游企业支付相应的欠款。

Be detailed in [2020.docx](https://github.com/guzy0324/block_chain_project/releases/download/v0.0.0/2020.docx).

## Implementation:

- Database:

    |债权人(主码)|债务人(主码)|还款日期(主码)|挂起(主码)|金额  |
    |-----------|-----------|-------------|---------|-----|
    |creditor   |debtor     |ddl          |pending  |value|

- 功能一：债权人发起，按主码如有记录直接修改value，否则插入一条记录

- 功能二：债权人发起，减少记录金额，插入一条新记录金额为减少的金额（“插入”同样按照功能一的方式）

- 功能三：债权人发起，向银行账户申请转移债券，设置pending为银行账户；银行可以取消pending（设为0）将债权人改为自己。

- 功能四：债权人发起，（判断时间）删除一条记录