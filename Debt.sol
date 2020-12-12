pragma solidity>=0.4.24 <0.6.11;
pragma experimental ABIEncoderV2;

import "./Table.sol";

contract Debt
{
    // event
    event RegisterEvent(int256 ret, string account, uint256 asset_value);
    event TransferEvent(int256 ret, string from_account, string to_account, uint256 amount);

    constructor() public
    {
        // 构造函数中创建debt表
        createTable();
    }

    string id = "0";
    function createTable() private
    {
        TableFactory tf = TableFactory(0x1001);
        // 应收账款表, key : account, field : asset_value
        // |主码   |债权人     |债务人      |还款日期     |挂起(主码)|金额    |
        // |------|-----------|-----------|-------------|---------|-------|
        // |id    |creditor   |debtor     |ddl          |pending  |value  |
        // |string|address    |address    |uint256      |address  |uint256|
        //
        // 创建表
        tf.createTable("debt", "id", "creditor,debtor,ddl,pending,value");
    }

    function openTable() private returns(Table)
    {
        TableFactory tf = TableFactory(0x1001);
        Table table = tf.openTable("debt");
        return table;
    }

    struct debt
    {
        address creditor;
        address debtor;
        uint256 ddl;
        address pending;
        uint256 value;
    }

    /*
    描述 : 查询相关debt
    参数 ：
            无

    返回值：
            参数一： 成功返回0, 账户不存在返回-1
            参数二： 第一个参数为0时有效，debt
    */
    function select() public returns (int256, debt [] memory)
    {
        // 打开表
        Table table = openTable();
        // 查询
        Condition condition;

        condition = table.newCondition();
        condition.EQ("creditor", int256(msg.sender));
        Entries entries0 = table.select(id, condition);

        condition = table.newCondition();
        condition.EQ("debtor", int256(msg.sender));
        Entries entries1 = table.select(id, condition);

        int256 total_size = entries0.size() + entries1.size();
        debt[] memory debt_list;
        if (total_size == 0)
        {
            return (-1, debt_list);
        }
        debt_list = new debt[](uint256(total_size));
        int256 i = 0;
        Entry entry;

        for (; i < entries0.size(); ++i)
        {
            entry = entries1.get(i);
            debt_list[uint256(i)].creditor = address(entry.getInt("creditor"));
            debt_list[uint256(i)].debtor = address(entry.getInt("debtor"));
            debt_list[uint256(i)].ddl = uint256(entry.getInt("ddl"));
            debt_list[uint256(i)].pending = address(entry.getInt("pending"));
            debt_list[uint256(i)].value = uint256(entry.getInt("value"));
        }

        for (; i < entries1.size(); ++i)
        {
            entry = entries1.get(i);
            debt_list[uint256(i)].creditor = address(entry.getInt("creditor"));
            debt_list[uint256(i)].debtor = address(entry.getInt("debtor"));
            debt_list[uint256(i)].ddl = uint256(entry.getInt("ddl"));
            debt_list[uint256(i)].pending = address(entry.getInt("pending"));
            debt_list[uint256(i)].value = uint256(entry.getInt("value"));
        }

        return (0, debt_list);
    }
}