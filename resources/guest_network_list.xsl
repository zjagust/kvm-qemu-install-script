<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text"/>
  <xsl:template match="text()"/>
  <xsl:strip-space elements="*"/>
  <xsl:template match="network">
    <xsl:text>   FORWARD MODE: </xsl:text>
    <xsl:value-of select="(forward/@mode)[1]"/>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>   GATEWAY: </xsl:text>
    <xsl:value-of select="(ip/@address)[1]"/>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>   NETMASK: </xsl:text>
    <xsl:value-of select="(ip/@netmask)[1]"/>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>   RANGE START: </xsl:text>
    <xsl:value-of select="(ip/dhcp/range/@start)[1]"/>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>   RANGE END: </xsl:text>
    <xsl:value-of select="(ip/dhcp/range/@end)[1]"/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>
</xsl:stylesheet>