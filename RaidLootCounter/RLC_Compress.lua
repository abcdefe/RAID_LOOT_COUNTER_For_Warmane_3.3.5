local addonName, ns = ...
local M = {}

-- ============================================================================
-- 压缩 / 编码模块 (Compress Module)
-- WA 式压缩导出：JSON 文本 → LZW 压缩 → 6-bit B64 编码 → 纯可打印 ASCII
-- 参考: WeakAuras LibCompress.lua / Transmission.lua（只移植 LZW 与 B64 查找表）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- LZW 压缩 / 解压（逐字移植自 WeakAuras 的 LibCompress，无 bit 库依赖）
-- ----------------------------------------------------------------------------
local type = type
local tostring = tostring
local unpack = unpack
local table_concat = table.concat
local string_char = string.char
local string_byte = string.byte

-- encode is used to uniquely encode a number into a sequence of bytes that can be decoded using decode()
-- the bytes returned by this do not contain "\000"
local bytes = {}
local function encode(x)
    for k = 1, #bytes do
        bytes[k] = nil
    end

    bytes[#bytes + 1] = x % 255
    x=math.floor(x/255)

    while x > 0 do
        bytes[#bytes + 1] = x % 255
        x=math.floor(x/255)
    end
    if #bytes == 1 and bytes[1] > 0 and bytes[1] < 250 then
        return string_char(bytes[1])
    else
        for i = 1, #bytes do
            bytes[i] = bytes[i] + 1
        end
        return string_char(256 - #bytes, unpack(bytes))
    end
end

--decode converts a unique character sequence into its equivalent number, from ss, beginning at the ith char.
-- returns the decoded number and the count of characters used in the decode process.
local function decode(ss, i)
    i = i or 1
    local a = string_byte(ss, i, i)
    if a > 249 then
        local r = 0
        a = 256 - a
        for n = i + a, i + 1, -1 do
            r = r * 255 + string_byte(ss, n, n) - 1
        end
        return r, a + 1
    else
        return a, 1
    end
end

-- Compresses the given uncompressed string.
-- Unless the uncompressed string starts with "\002", this is guaranteed to return a string equal to or smaller than
-- the passed string.
-- the returned string will only contain "\000" characters in rare circumstances, and will contain none if the
-- source string has none.
local dict = {}
function M.CompressLZW(uncompressed)
    if type(uncompressed) == "string" then
        local dict_size = 256
        for k in pairs(dict) do
            dict[k] = nil
        end

        local result = {"\002"}
        local w = ''
        local ressize = 1

        for i = 0, 255 do
            dict[string_char(i)] = i
        end

        for i = 1, #uncompressed do
            local c = uncompressed:sub(i, i)
            local wc = w..c
            if dict[wc] then
                w = wc
            else
                dict[wc] = dict_size
                dict_size = dict_size + 1
                local r = encode(dict[w])
                ressize = ressize + #r
                result[#result + 1] = r
                w = c
            end
        end

        if w then
            local r = encode(dict[w])
            ressize = ressize + #r
            result[#result + 1] = r
        end

        if (#uncompressed + 1) > ressize then
            return table_concat(result)
        else
            return string_char(1)..uncompressed
        end
    else
        return nil, "Can only compress strings"
    end
end

-- if the passed string is a compressed string, this will decompress it and return the decompressed string.
-- Otherwise it return an error message
-- compressed strings are marked by beginning with "\002"
function M.DecompressLZW(compressed)
    if type(compressed) == "string" then
        if compressed:sub(1, 1) ~= "\002" then
            return nil, "Can only decompress LZW compressed data ("..tostring(compressed:sub(1, 1))..")"
        end

        compressed = compressed:sub(2)
        local dict_size = 256

        for k in pairs(dict) do
            dict[k] = nil
        end

        for i = 0, 255 do
            dict[i] = string_char(i)
        end

        local result = {}
        local t = 1
        local delta, k
        k, delta = decode(compressed, t)
        t = t + delta
        result[#result + 1] = dict[k]

        local w = dict[k]
        local entry
        while t <= #compressed do
            k, delta = decode(compressed, t)
            t = t + delta
            entry = dict[k] or (w..w:sub(1, 1))
            result[#result + 1] = entry
            dict[dict_size] = w..entry:sub(1, 1)
            dict_size = dict_size + 1
            w = entry
        end
        return table_concat(result)
    else
        return nil, "Can only uncompress strings"
    end
end

-- ----------------------------------------------------------------------------
-- 6-bit B64 查找表（抄自 WeakAuras Transmission.lua，仅抄这两个表）
-- ----------------------------------------------------------------------------
local bytetoB64 = {
    [0]="a","b","c","d","e","f","g","h",
    "i","j","k","l","m","n","o","p",
    "q","r","s","t","u","v","w","x",
    "y","z","A","B","C","D","E","F",
    "G","H","I","J","K","L","M","N",
    "O","P","Q","R","S","T","U","V",
    "W","X","Y","Z","0","1","2","3",
    "4","5","6","7","8","9","(",")"
}

local B64tobyte = {
    a =  0,  b =  1,  c =  2,  d =  3,  e =  4,  f =  5,  g =  6,  h =  7,
    i =  8,  j =  9,  k = 10,  l = 11,  m = 12,  n = 13,  o = 14,  p = 15,
    q = 16,  r = 17,  s = 18,  t = 19,  u = 20,  v = 21,  w = 22,  x = 23,
    y = 24,  z = 25,  A = 26,  B = 27,  C = 28,  D = 29,  E = 30,  F = 31,
    G = 32,  H = 33,  I = 34,  J = 35,  K = 36,  L = 37,  M = 38,  N = 39,
    O = 40,  P = 41,  Q = 42,  R = 43,  S = 44,  T = 45,  U = 46,  V = 47,
    W = 48,  X = 49,  Y = 50,  Z = 51,["0"]=52,["1"]=53,["2"]=54,["3"]=55,
    ["4"]=56,["5"]=57,["6"]=58,["7"]=59,["8"]=60,["9"]=61,["("]=62,[")"]=63
}

-- ----------------------------------------------------------------------------
-- B64 编码 / 解码（LSB-first 流式，纯算术实现，无 bit 库，中间值恒 < 2^14）
-- ----------------------------------------------------------------------------

-- EncodeB64: 字节流 → 6-bit B64 字符流（与 DecodeB64 严格互逆）
function M.EncodeB64(str)
    local bitfield = 0
    local bitfield_len = 0
    local out = {}
    for i = 1, #str do
        local code = string.byte(str, i)
        bitfield = bitfield + code * 2^bitfield_len   -- 即 lshift
        bitfield_len = bitfield_len + 8
        while bitfield_len >= 6 do
            out[#out + 1] = bytetoB64[bitfield % 64]    -- 即 band(bitfield, 63)
            bitfield = math.floor(bitfield / 64)        -- 即 rshift 6
            bitfield_len = bitfield_len - 6
        end
    end
    if bitfield_len > 0 then out[#out + 1] = bytetoB64[bitfield % 64] end   -- 末尾不足6位的零填充
    return table.concat(out)
end

-- DecodeB64: 6-bit B64 字符流 → 字节流（与 EncodeB64 严格互逆，尾部零填充自然对齐）
function M.DecodeB64(str)
    local bitfield = 0
    local bitfield_len = 0
    local out = {}
    for i = 1, #str do
        local ch = B64tobyte[str:sub(i, i)]
        bitfield = bitfield + (ch or 0) * 2^bitfield_len
        bitfield_len = bitfield_len + 6
        while bitfield_len >= 8 do
            out[#out + 1] = string.char(bitfield % 256)
            bitfield = math.floor(bitfield / 256)
            bitfield_len = bitfield_len - 8
        end
    end
    return table.concat(out)
end

-- ----------------------------------------------------------------------------
-- 对外接口
-- ----------------------------------------------------------------------------

-- Encode: 原始文本 → 可打印导出串（EncodeB64(CompressLZW(text))）
function M.Encode(text)
    -- 空串保护：LibCompress 的 LZW 收尾块 `if w then` 中 w 初始为 ''（空串为真值），
    -- 空输入会去查 dict['']（未 seed）而崩溃。空输入用 \001（未压缩）标记编码，
    -- M.Decode 会正确还原为空串。
    if not text or text == "" then
        return M.EncodeB64("\001")
    end
    return M.EncodeB64(M.CompressLZW(text))
end

-- Decode: 可打印导出串 → 原始文本（按首字节分发：\002 → LZW 解压；\001 → 未压缩；其它 → nil）
function M.Decode(str)
    local binary = M.DecodeB64(str)
    local marker = binary:sub(1, 1)
    if marker == "\002" then
        return M.DecompressLZW(binary)
    elseif marker == "\001" then
        return binary:sub(2)
    else
        return nil
    end
end

ns.Compress = M
