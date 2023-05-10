/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesInterphone]    Script Date: 10/05/2023 9:20:32 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--	2021-11-01	Sebastián Jaramillo: Se incluye RN LATAM Contrato Nuevo EYP
--	2021-12-06	Sebastián Jaramillo: Nueva RN American Airlines	
--	2022-01-31	Sebastián Jaramillo: Nueva RN Ultra Air
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesInterphone](
	@ServiceHeaderId BIGINT,
	@ServiceTypeId INT,
	@CompanyId INT,
	@BillingToCompany INT,
	@AirportId INT,
	@DateService DATE
)
RETURNS @Result TABLE(
	ROW INT IDENTITY, 
	StartDate DATETIME, 
	EndDate DATETIME, 
	IsAdditionalService BIT, 
	AdditionalQuantity INT, 
	AdditionalServiceName VARCHAR(150)
	)
AS
BEGIN
	DECLARE @TimeLeftover FLOAT=0

	DECLARE @ServiceDetail AS CIOReglaNegocio.ServiceDetailType
	INSERT	@ServiceDetail
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
			'INTERPHONE',
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) Time_total, 
			ISNULL(DS.cantidad, 1)
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId = 27 /*Interphone*/ AND
			DS.EncabezadoServicioId = @ServiceHeaderId 

	IF (SELECT SUM(Cantidad) FROM @ServiceDetail) = 0  RETURN 

	--ULTRA AIR / ULTRA AIR
	IF (@CompanyId=259 AND @BillingToCompany=259)
	BEGIN
		IF (@DateService >= '2022-01-20')
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)

			RETURN
		END
	END

	--AMERICAN AIRLINES / AMERICAN AIRLINES
	IF (@CompanyId=43 AND @BillingToCompany=43)
	BEGIN
		IF (@DateService >= '2021-12-04')
		BEGIN
			INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)

			RETURN
		END
	END

	----IF (@CompanyId IN (/* 7 INACTIVO EN EL AT */44) AND @DateService <= '2016-02-15') --VIVA PERU
	----BEGIN
	----	IF(@AirportId IN (11/* BGA */, 55/* SMR */, 34 /*LET*/, 18/*CUC*/, 31/*IBE'*/, 60 /*VVC*/, 40/*MTR*/ , 59 /*VUP*/))
	----	BEGIN
	----		INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
	----		RETURN
	----	END
	----END

	IF (@CompanyId = 60 AND @BillingToCompany = 90) --VIVA COLOMBIA                           
	BEGIN
		INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
		RETURN
	END

	IF (@CompanyId = 44 AND @BillingToCompany = 44) --LAN
	BEGIN
		IF (@DateService >= '2021-10-27') --Ya EYP no tiene interphone incluido
		BEGIN
			IF (@AirportId IN (5, 11, 17, 18, 34, 40, 45, 59)) --Se incluye 1 cantidad en estas bases ADZ, BGA, CTG, CUC, LET, MTR, PEI, VUP
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
			END
			ELSE
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
			END
		END

		IF (@DateService BETWEEN '2020-09-01' AND '2021-10-26')
		BEGIN
			IF (@AirportId IN (5, 11, 17, 18, 25, 34, 40, 45, 59)) --Se incluye 1 cantidad en estas bases ADZ, BGA, CTG, CUC, EYP, LET, MTR, PEI, VUP
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1)
			END
			ELSE
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
			END
		END
	END

	RETURN
END